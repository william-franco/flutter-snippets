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

// Result (Functional programming)
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

// Generic model for errors
class InfoErrorModel {
  final int? statusCode;
  final String? title;
  final String? description;

  const InfoErrorModel({this.statusCode, this.title, this.description});

  InfoErrorModel copyWith({
    int? statusCode,
    String? title,
    String? description,
  }) => InfoErrorModel(
    statusCode: statusCode ?? this.statusCode,
    title: title ?? this.title,
    description: description ?? this.description,
  );

  factory InfoErrorModel.fromJson(Map<String, dynamic> json) => InfoErrorModel(
    statusCode: json['status_code'],
    title: json['title'],
    description: json['description'],
  );

  Map<String, dynamic> toJson() => {
    'status_code': statusCode,
    'title': title,
    'description': description,
  };
}

// Model
class UserModel {
  final String? name;

  UserModel({this.name});
}

// Repository
typedef UserResult = Result<UserModel, Exception>; // Functional programming

abstract interface class UserRepository {
  Future<UserResult> getUserData();
}

class UserRepositoryImpl implements UserRepository {
  @override
  Future<UserResult> getUserData() async {
    try {
      await Future.delayed(Duration(seconds: 4));
      return Success(value: UserModel(name: 'John Doe'));
    } catch (error) {
      return Error(error: Exception('An error occurred.'));
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

  AppState<UserModel> _userState = InitialState();

  @override
  AppState<UserModel> get userState => _userState;

  @override
  Future<void> getUserData() async {
    _emit(LoadingState());

    final result = await userRepository.getUserData();

    final state = result.fold<AppState<UserModel>>(
      onSuccess: (value) => SuccessState(data: value),
      onError: (error) => ErrorState(message: '$error'),
    );

    _emit(state);
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
            onPressed: () async {
              await _refreshUser();
            },
          ),
        ],
      ),
      body: Center(
        child: RefreshIndicator(
          onRefresh: () async {
            await _refreshUser();
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

  void _snackBarWidget(String title, String description, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14.0,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              description,
              style: TextStyle(
                fontSize: 12.0,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _refreshUser() async {
    if (!context.mounted) return;

    // Mock api response.
    final infoSuccess = InfoErrorModel(
      statusCode: 200,
      title: 'Success',
      description: 'Updated user.',
    );
    final infoError = InfoErrorModel(
      statusCode: 400,
      title: 'Error',
      description: 'User not updated.',
    );

    try {
      await userViewModel.getUserData().then((_) {
        _snackBarWidget(
          infoSuccess.title ?? '',
          infoSuccess.description ?? '',
          Colors.green,
        );
      });
    } catch (error) {
      _snackBarWidget(
        infoError.title ?? '',
        infoError.description ?? '',
        Colors.red,
      );
    }
  }
}
