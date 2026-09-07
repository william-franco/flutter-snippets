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
sealed class StatePattern<T> {
  const StatePattern();
}

final class InitialState<T> extends StatePattern<T> {
  const InitialState();
}

final class LoadingState<T> extends StatePattern<T> {
  const LoadingState();
}

final class SuccessState<T> extends StatePattern<T> {
  final T data;

  const SuccessState({required this.data});
}

final class ErrorState<T> extends StatePattern<T> {
  final String message;

  const ErrorState({required this.message});
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
abstract interface class UserRepository {
  Future<UserModel> getUserData();
}

class UserRepositoryImpl implements UserRepository {
  @override
  Future<UserModel> getUserData() async {
    try {
      await Future.delayed(Duration(seconds: 4));
      return UserModel(name: 'John Doe');
    } catch (error) {
      throw Exception('An error occurred.');
    }
  }
}

// ViewModel
typedef UserState = StatePattern<UserModel>;

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
    try {
      _emit(LoadingState());
      final result = await userRepository.getUserData();
      _emit(SuccessState(data: result));
    } catch (error) {
      _emit(ErrorState(message: '$error'));
    }
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
        child: ListenableBuilder(
          listenable: userViewModel,
          builder: (context, child) {
            return switch (userViewModel.userState) {
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
