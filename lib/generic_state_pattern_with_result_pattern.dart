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
sealed class StatePattern<S, E extends Exception> {
  const StatePattern();
}

final class InitialState<S, E extends Exception> extends StatePattern<S, E> {
  const InitialState();
}

final class LoadingState<S, E extends Exception> extends StatePattern<S, E> {
  const LoadingState();
}

final class SuccessState<S, E extends Exception> extends StatePattern<S, E> {
  final S data;

  const SuccessState({required this.data});
}

final class ErrorState<S, E extends Exception> extends StatePattern<S, E> {
  final E error;

  const ErrorState({required this.error});
}

// ResultPattern Pattern
sealed class ResultPattern<S, E extends Exception> {
  const ResultPattern();

  T fold<T>({
    required T Function(S value) onSuccess,
    required T Function(E error) onError,
  }) {
    switch (this) {
      case SuccessResult(value: final v):
        return onSuccess(v);
      case ErrorResult(error: final e):
        return onError(e);
    }
  }
}

final class SuccessResult<S, E extends Exception> extends ResultPattern<S, E> {
  final S value;

  const SuccessResult({required this.value});
}

final class ErrorResult<S, E extends Exception> extends ResultPattern<S, E> {
  final E error;

  const ErrorResult({required this.error});
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
typedef UserResult = ResultPattern<UserModel, UserException>;

abstract interface class UserRepository {
  Future<UserResult> findOneUser();
}

class UserRepositoryImpl implements UserRepository {
  @override
  Future<UserResult> findOneUser() async {
    try {
      await Future.delayed(Duration(seconds: 4));
      return SuccessResult(value: UserModel(name: 'John Doe'));
    } catch (error) {
      return ErrorResult(error: UserException('An error occurred.'));
    }
  }
}

// ViewModel
typedef UserState = StatePattern<UserModel, UserException>;

typedef _ViewModel = ChangeNotifier;

abstract interface class UserViewModel extends _ViewModel {
  UserState get userState;

  Future<void> getUserData();
}

class UserViewModelImpl extends _ViewModel implements UserViewModel {
  final UserRepository userRepository;

  UserViewModelImpl({required this.userRepository});

  UserState _userState = InitialState();

  @override
  UserState get userState => _userState;

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
    _userState = newState;
    notifyListeners();
    debugPrint('User state: $userState');
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
        title: const Text('User Info'),
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
        child: RefreshIndicator(
          onRefresh: () async {
            await _getUserData();
          },
          child: ListenableBuilder(
            listenable: userViewModel,
            builder: (context, child) {
              return switch (userViewModel.userState) {
                InitialState() => const SizedBox.shrink(),
                LoadingState() => const CircularProgressIndicator(),
                SuccessState(data: final user) => Text('User: ${user.name}'),
                ErrorState(error: final e) => Text('Error: ${e.message}'),
              };
            },
          ),
        ),
      ),
    );
  }
}
