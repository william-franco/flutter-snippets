import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snippets',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.system,
      home: const UserView(),
    );
  }
}

// Result Pattern
sealed class Result<S, E extends Exception> {
  const Result();

  T fold<T>({
    required T Function(S value) onSuccess,
    required T Function(E error) onError,
  }) {
    switch (this) {
      case Success(value: final v):
        return onSuccess(v);
      case Error(error: final e):
        return onError(e);
    }
  }
}

final class Success<S, E extends Exception> extends Result<S, E> {
  final S value;

  const Success({required this.value});
}

final class Error<S, E extends Exception> extends Result<S, E> {
  final E error;

  const Error({required this.error});
}

// Model
class UserModel {
  final String? name;

  UserModel({this.name});
}

// Repository
typedef UserResult = Result<UserModel, Exception>;

abstract interface class UserRepository {
  Future<UserResult> findOneUser();
}

class UserRepositoryImpl implements UserRepository {
  @override
  Future<UserResult> findOneUser() async {
    try {
      await Future.delayed(Duration(seconds: 4));
      return Success(value: UserModel(name: 'John Doe'));
    } catch (error) {
      return Error(error: Exception('An error occurred.'));
    }
  }
}

// ViewModel
typedef UserState = StateController<UserModel>;

abstract interface class UserViewModel {
  UserState get controller;

  Future<void> getUserData();
}

class UserViewModelImpl implements UserViewModel {
  final UserRepository userRepository;

  UserViewModelImpl({required this.userRepository});

  final UserState _controller = UserState.loading();

  @override
  UserState get controller => _controller;

  @override
  Future<void> getUserData() async {
    _controller.setLoading();

    final result = await userRepository.findOneUser();

    result.fold(
      onSuccess: (value) => _controller.setData(value),
      onError: (error) => _controller.setError('$error'),
    );
  }
}

// View
class UserView extends StatefulWidget {
  const UserView({super.key});

  @override
  State<UserView> createState() => _UserViewState();
}

class _UserViewState extends State<UserView> {
  late final UserRepository userRepository;
  late final UserViewModel userViewModel;

  @override
  void initState() {
    super.initState();
    userRepository = UserRepositoryImpl();
    userViewModel = UserViewModelImpl(userRepository: userRepository);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _getUserData();
    });
  }

  @override
  void dispose() {
    userViewModel.controller.dispose();
    super.dispose();
  }

  Future<void> _getUserData() async {
    await userViewModel.getUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () async {
              await _getUserData();
            },
          ),
        ],
      ),
      body: Center(
        child: StateBuilderWidget<UserState>(
          controller: userViewModel.controller,
          builder: (context, state) {
            return state.value.when(
              loading: () => const CircularProgressIndicator(),
              data: (user) => Text('User: ${user.name}'),
              error: (message) => Text('Error: $message'),
            );
          },
        ),
      ),
    );
  }
}

// Generic State Pattern
class StateValue<T> {
  final T? data;
  final Object? error;
  final bool isLoading;

  StateValue._({this.data, this.error, required this.isLoading});

  factory StateValue.loading() => StateValue._(isLoading: true);
  factory StateValue.error(Object error) =>
      StateValue._(isLoading: false, error: error);
  factory StateValue.data(T data) => StateValue._(isLoading: false, data: data);

  Widget when({
    required Widget Function() loading,
    required Widget Function(Object error) error,
    required Widget Function(T data) data,
  }) {
    if (isLoading) {
      return loading();
    } else if (this.error != null) {
      return error(this.error!);
    } else if (this.data != null) {
      return data(this.data as T);
    }
    throw StateError('Invalid state: no data, error, or loading.');
  }
}

// State management with when condition based on StateValue<T>
class StateController<T> extends ChangeNotifier {
  StateValue<T> _state;

  StateController(this._state);

  factory StateController.loading() => StateController<T>(StateValue.loading());

  factory StateController.data(T data) =>
      StateController<T>(StateValue.data(data));

  factory StateController.error(Object error) =>
      StateController<T>(StateValue.error(error));

  StateValue<T> get value => _state;

  void _update(StateValue<T> newValue) {
    _state = newValue;
    notifyListeners();
    debugPrint('State: $_state');
  }

  void setLoading() => _update(StateValue.loading());
  void setError(Object error) => _update(StateValue.error(error));
  void setData(T data) => _update(StateValue.data(data));

  @override
  String toString() => 'StateController<$T>(state: $_state)';
}

@protected
typedef StateBuilder<C extends ChangeNotifier> =
    Widget Function(BuildContext context, C controller);

class StateBuilderWidget<C extends ChangeNotifier> extends StatelessWidget {
  final C controller;
  final StateBuilder<C> builder;

  const StateBuilderWidget({
    super.key,
    required this.controller,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => builder(context, controller),
    );
  }
}
