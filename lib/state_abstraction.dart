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

// Generic State Pattern
sealed class AppState<T> {
  const AppState();
}

final class InitialState<T> extends AppState<T> {
  const InitialState();
}

final class LoadingState<T> extends AppState<T> {
  const LoadingState();
}

final class SuccessState<T> extends AppState<T> {
  final T data;

  const SuccessState({required this.data});
}

final class ErrorState<T> extends AppState<T> {
  final String message;

  const ErrorState({required this.message});
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
typedef _ViewModel = StateManagement<UserState>;

typedef UserState = AppState<UserModel>;

abstract interface class UserViewModel extends _ViewModel {
  UserViewModel(super.initialState);

  Future<void> getUserData();
}

class UserViewModelImpl extends _ViewModel implements UserViewModel {
  final UserRepository userRepository;

  UserViewModelImpl({required this.userRepository}) : super(InitialState());

  @override
  Future<void> getUserData() async {
    _emit(LoadingState());

    final result = await userRepository.findOneUser();

    final userState = result.fold<UserState>(
      onSuccess: (value) => SuccessState(data: value),
      onError: (error) => ErrorState(message: '$error'),
    );

    _emit(userState);
  }

  void _emit(UserState newState) {
    emitState(newState);
    debugPrint('User state: $state');
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
        child: StateBuilderWidget<UserViewModel, UserState>(
          viewModel: userViewModel,
          builder: (context, userState) {
            return switch (userState) {
              InitialState() => const SizedBox.shrink(),
              LoadingState() => const CircularProgressIndicator(),
              SuccessState(data: final user) => Text('User: ${user.name}'),
              ErrorState(message: final message) => Text('Error: $message'),
            };
          },
        ),
      ),
    );
  }
}

// StateManagement abstracted
abstract class StateManagement<T> extends ChangeNotifier {
  T _state;

  StateManagement(T initialState) : _state = initialState;

  T get state => _state;

  @protected
  void emitState(T newState) {
    if (identical(_state, newState)) return;
    _state = newState;
    debugPrint('StateManagement<$T> -> $newState');
    notifyListeners();
  }

  @override
  String toString() => 'StateManagement<$T>(state: $_state)';
}

// Builder for StateManagement
@protected
typedef StateBuilder<S> = Widget Function(BuildContext context, S state);

class StateBuilderWidget<V extends StateManagement<S>, S>
    extends StatelessWidget {
  final V viewModel;
  final StateBuilder<S> builder;
  final Widget? child;

  const StateBuilderWidget({
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
