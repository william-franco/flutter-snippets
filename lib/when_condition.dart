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

  UserModel copyWith({String? name}) {
    return UserModel(name: name ?? this.name);
  }
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
typedef _ViewModel = AsyncStateManagement<UserModel>;

abstract interface class UserViewModel extends _ViewModel {
  UserViewModel(super.initialState);

  Future<void> getUserData();
}

class UserViewModelImpl extends _ViewModel implements UserViewModel {
  final UserRepository userRepository;

  UserViewModelImpl({required this.userRepository}) : super(StateLoading());

  @override
  Future<void> getUserData() async {
    setLoading();

    final result = await userRepository.findOneUser();

    result.fold(
      onSuccess: (value) => setData(value),
      onError: (error) => setError('$error'),
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
    userViewModel.dispose();
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
        child: AsyncStateBuilderWidget<UserViewModel, UserModel>(
          viewModel: userViewModel,
          builder: (context, userState) {
            return userState.when(
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

// Generic State Pattern for AsyncStateManagement<T>
sealed class StateValue<T> {
  const StateValue();

  R when<R>({
    required R Function() loading,
    required R Function(Object error) error,
    required R Function(T data) data,
  });
}

class StateLoading<T> extends StateValue<T> {
  const StateLoading();

  @override
  R when<R>({
    required R Function() loading,
    required R Function(Object error) error,
    required R Function(T data) data,
  }) => loading();
}

class StateError<T> extends StateValue<T> {
  final Object errorValue;

  const StateError(this.errorValue);

  @override
  R when<R>({
    required R Function() loading,
    required R Function(Object error) error,
    required R Function(T data) data,
  }) => error(errorValue);
}

class StateData<T> extends StateValue<T> {
  final T dataValue;

  const StateData(this.dataValue);

  @override
  R when<R>({
    required R Function() loading,
    required R Function(Object error) error,
    required R Function(T data) data,
  }) => data(dataValue);
}

abstract class AsyncStateManagement<T> extends ChangeNotifier {
  StateValue<T> _state;

  AsyncStateManagement(StateValue<T> initialState) : _state = initialState;

  StateValue<T> get state => _state;

  @protected
  void emitState(StateValue<T> newState) {
    if (_state == newState) return;
    _state = newState;
    debugPrint('AsyncStateManagement<$T> -> $newState');
    notifyListeners();
  }

  @override
  String toString() => 'AsyncStateManagement<$T>(state: $_state)';

  @protected
  void setLoading() => emitState(const StateLoading());

  @protected
  void setError(Object error) => emitState(StateError<T>(error));

  @protected
  void setData(T data) => emitState(StateData<T>(data));
}

// Builder for AsyncStateManagement<T>
@protected
typedef AsyncStateBuilder<S> =
    Widget Function(BuildContext context, StateValue<S> state);

class AsyncStateBuilderWidget<V extends AsyncStateManagement<S>, S>
    extends StatelessWidget {
  final V viewModel;
  final AsyncStateBuilder<S> builder;
  final Widget? child;

  const AsyncStateBuilderWidget({
    super.key,
    required this.viewModel,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      child: child,
      builder: (context, child) {
        return builder(context, viewModel.state);
      },
    );
  }
}
