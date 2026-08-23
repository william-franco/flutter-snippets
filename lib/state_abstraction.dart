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
sealed class AppState<S, E extends Exception> {
  const AppState();
}

final class InitialState<S, E extends Exception> extends AppState<S, E> {
  const InitialState();
}

final class LoadingState<S, E extends Exception> extends AppState<S, E> {
  const LoadingState();
}

final class SuccessState<S, E extends Exception> extends AppState<S, E> {
  final S data;

  const SuccessState({required this.data});
}

final class ErrorState<S, E extends Exception> extends AppState<S, E> {
  final E error;

  const ErrorState({required this.error});
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

// Custom Exception
class UserException implements Exception {
  final String message;

  const UserException(this.message);

  @override
  String toString() => 'UserException: $message';
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
typedef UserResult = Result<UserModel, UserException>;

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
      return Error(error: UserException('An error occurred.'));
    }
  }
}

// ViewModel
typedef UserState = AppState<UserModel, UserException>;

typedef _ViewModel = StateManagement<UserState>;

abstract interface class UserViewModel extends _ViewModel {
  Future<void> getUserData();
}

class UserViewModelImpl extends _ViewModel implements UserViewModel {
  final UserRepository userRepository;

  UserViewModelImpl({required this.userRepository});

  @override
  UserState build() => const InitialState();

  @override
  Future<void> getUserData() async {
    _emit(LoadingState());

    final result = await userRepository.findOneUser();

    final userState = result.fold<UserState>(
      onSuccess: (value) => SuccessState(data: value),
      onError: (error) => ErrorState(error: error),
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
              ErrorState(error: final e) => Text('Error: ${e.message}'),
            };
          },
        ),
      ),
    );
  }
}

// StateManagement abstracted
abstract class StateManagement<T> extends ChangeNotifier {
  late T _state;

  StateManagement() {
    _state = build();
  }

  @protected
  T build();

  T get state => _state;

  @protected
  void emitState(T newState) {
    if (_state == newState) return;
    _state = newState;
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
