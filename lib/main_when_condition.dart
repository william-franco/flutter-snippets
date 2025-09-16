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

// Model
class UserModel {
  final String? name;

  UserModel({this.name});
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
typedef _ViewModel = ChangeNotifier;

abstract interface class UserViewModel extends _ViewModel {
  StateController<UserModel> get userState;

  Future<void> getUserData();
}

class UserViewModelImpl extends _ViewModel implements UserViewModel {
  final UserRepository userRepository;

  UserViewModelImpl({required this.userRepository});

  final _userState = StateController<UserModel>();

  @override
  StateController<UserModel> get userState => _userState;

  @override
  Future<void> getUserData() async {
    try {
      _userState.setLoading();
      final user = await userRepository.getUserData();
      _userState.setData(user);
    } catch (error) {
      _userState.setError(error);
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
            listenable: userViewModel.userState,
            builder: (context, child) {
              return userViewModel.userState.state.when(
                loading: () => const CircularProgressIndicator(),
                data: (user) => Text('Usuer: ${user.name}'),
                error: (message) => Text('Error: $message'),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Representa o estado genérico de uma operação.
///
/// Usa `sealed class` para garantir que o `switch` seja exaustivo,
/// melhorando a segurança de tipo.
sealed class StateValue<T> {
  const StateValue();

  /// Facilita o consumo do estado na View.
  Widget when({
    required Widget Function() loading,
    required Widget Function(T value) data,
    required Widget Function(Object error) error,
  }) {
    return switch (this) {
      Loading<T>() => loading(),
      Data<T>(value: final v) => data(v),
      ErrorState<T>(exception: final e) => error(e),
    };
  }
}

/// Estado de carregamento.
final class Loading<T> extends StateValue<T> {
  const Loading();
}

/// Estado com dado.
final class Data<T> extends StateValue<T> {
  final T value;
  const Data(this.value);
}

/// Estado de erro.
final class ErrorState<T> extends StateValue<T> {
  final Object exception;
  const ErrorState(this.exception);
}

/// Controller genérico que expõe um estado [StateValue] e notifica ouvintes.
///
/// Ele mesmo é um `Listenable`, garantindo compatibilidade com:
/// - [ListenableBuilder]
/// - [AnimatedBuilder]
/// - [ValueListenableBuilder] (com adaptação)
///
/// Pode ser usado diretamente ou herdado em ViewModels.
class StateController<T> with ChangeNotifier implements Listenable {
  StateValue<T> _state;

  /// Cria um controller com um estado inicial opcional.
  StateController([StateValue<T>? initial])
    : _state = initial ?? const Loading();

  /// Retorna o estado atual.
  StateValue<T> get state => _state;

  /// Define um novo estado e notifica ouvintes somente se mudou.
  set state(StateValue<T> newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
      debugPrint('StateController<$T> -> $newState');
    }
  }

  /// Atalhos para facilitar uso no ViewModel.
  void setLoading() => state = const Loading();
  void setError(Object e) => state = ErrorState(e);
  void setData(T data) => state = Data(data);

  @override
  String toString() => 'StateController<$T>(state: $_state)';
}
