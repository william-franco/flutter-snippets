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

// Model
class UserModel {
  final String? name;

  UserModel({this.name});
}

// Repository
typedef UserResult = (UserModel? user, Exception? exception); // Records

abstract interface class UserRepository {
  Future<UserResult> getUserData();
}

class UserRepositoryImpl implements UserRepository {
  @override
  Future<UserResult> getUserData() async {
    try {
      await Future.delayed(Duration(seconds: 4));
      return (UserModel(name: 'John Doe'), null);
    } catch (error) {
      return (null, Exception('An error occurred.'));
    }
  }
}

// ViewModel
typedef _ViewModel = ChangeNotifier;

abstract interface class UserViewModel extends _ViewModel {
  AppState<UserModel?> get userState;

  Future<void> getUserData();
}

class UserViewModelImpl extends _ViewModel implements UserViewModel {
  final UserRepository userRepository;

  UserViewModelImpl({required this.userRepository});

  AppState<UserModel?> _userState = InitialState();

  @override
  AppState<UserModel?> get userState => _userState;

  @override
  Future<void> getUserData() async {
    _emit(LoadingState());

    final (user, error) = await userRepository.getUserData();

    if (user != null) {
      _emit(SuccessState(data: user));
    } else {
      _emit(ErrorState(message: '$error'));
    }
  }

  void _emit(AppState<UserModel> newValue) {
    if (_userState != newValue) {
      _userState = newValue;
      notifyListeners();
      debugPrint('User state: $_userState');
    }
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
    userViewModel.getUserData();
  }

  @override
  void dispose() {
    userViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Info'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () {
              userViewModel.getUserData();
            },
          ),
        ],
      ),
      body: Center(
        child: RefreshIndicator(
          onRefresh: () async {
            await userViewModel.getUserData();
          },
          child: ListenableBuilder(
            listenable: userViewModel,
            builder: (context, child) {
              return switch (userViewModel.userState) {
                InitialState() => const SizedBox.shrink(),
                LoadingState() => const CircularProgressIndicator(),
                SuccessState(data: final user) => Text('Usuer: ${user?.name}'),
                ErrorState(message: final message) => Text('Error: $message'),
              };
            },
          ),
        ),
      ),
    );
  }
}
