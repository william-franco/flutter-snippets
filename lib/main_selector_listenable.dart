import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snippets',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.system,
      home: const NumberView(),
    );
  }
}

// ViewModel
typedef _ViewModel = ChangeNotifier;

abstract interface class CounterViewModel extends _ViewModel {
  int get number1;
  int get number2;

  void add();
  void addTo1();
  void addTo2();
  void clear();
}

class CounterViewModelImpl extends _ViewModel implements CounterViewModel {
  int _number1 = 0;
  int _number2 = 1;

  @override
  int get number1 => _number1;

  @override
  int get number2 => _number2;

  @override
  void add() {
    _number1++;
    _number2++;
    notifyListeners();
  }

  @override
  void addTo1() {
    _number1++;
    notifyListeners();
  }

  @override
  void addTo2() {
    _number2++;
    notifyListeners();
  }

  @override
  void clear() {
    _number1 = 0;
    _number2 = 1;
    notifyListeners();
  }
}

// View
class NumberView extends StatefulWidget {
  const NumberView({super.key});

  @override
  State<NumberView> createState() => _NumberViewState();
}

class _NumberViewState extends State<NumberView> {
  late final CounterViewModel counterViewModel;

  @override
  void initState() {
    super.initState();
    counterViewModel = CounterViewModelImpl();
  }

  @override
  void dispose() {
    counterViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Counter with selector'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              counterViewModel.clear();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ListenableBuilder(
              listenable: counterViewModel,
              builder: (context, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      color: Colors.red,
                      padding: EdgeInsets.all(10),
                      child: Text('${counterViewModel.number1}'),
                    ),
                    SizedBox(height: 8.0),
                    Container(
                      color: Colors.green,
                      padding: EdgeInsets.all(10),
                      child: Text('${counterViewModel.number2}'),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: 8.0),
            SelectorBuilderWidget<CounterViewModel, int>(
              controller: counterViewModel,
              selector: (context, controller) => controller.number1,
              shouldRebuild: (prev, next) => prev != next,
              builder: (context, number1, child) {
                return Container(
                  color: Colors.red,
                  padding: EdgeInsets.all(10),
                  child: Text('$number1'),
                );
              },
            ),
            SizedBox(height: 8.0),
            SelectorBuilderWidget<CounterViewModel, int>(
              controller: counterViewModel,
              selector: (context, provider) => provider.number2,
              shouldRebuild: (prev, next) => prev != next,
              builder: (context, number2, child) {
                return Container(
                  color: Colors.green,
                  padding: EdgeInsets.all(10),
                  child: Text('$number2'),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        spacing: 8.0,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'all',
            onPressed: () {
              counterViewModel.add();
            },
            child: Text('all'),
          ),
          FloatingActionButton(
            heroTag: '1',
            onPressed: () {
              counterViewModel.addTo1();
            },
            child: Text('1'),
          ),
          FloatingActionButton(
            heroTag: '2',
            onPressed: () {
              counterViewModel.addTo2();
            },
            child: Text('2'),
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////////////////////////

@protected
typedef SelectorModel<C extends Listenable, T> =
    T Function(BuildContext context, C controller);

@protected
typedef SelectorFunctionBuilder<T> =
    Widget Function(BuildContext context, T model, Widget? child);

@protected
typedef ShouldRebuild<T> = bool Function(T previous, T next);

class SelectorBuilderWidget<C extends Listenable, T> extends StatefulWidget {
  final C controller;
  final SelectorModel<C, T> selector;
  final SelectorFunctionBuilder<T> builder;
  final ShouldRebuild<T>? shouldRebuild;
  final Widget? child;

  const SelectorBuilderWidget({
    super.key,
    required this.controller,
    required this.selector,
    required this.builder,
    this.shouldRebuild,
    this.child,
  });

  @override
  State<SelectorBuilderWidget<C, T>> createState() =>
      _SelectorBuilderWidgetState<C, T>();
}

class _SelectorBuilderWidgetState<C extends Listenable, T>
    extends State<SelectorBuilderWidget<C, T>> {
  late T _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.selector(context, widget.controller);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final newValue = widget.selector(context, widget.controller);

        final rebuild =
            widget.shouldRebuild?.call(_selectedValue, newValue) ??
            (_selectedValue != newValue);

        if (rebuild) {
          _selectedValue = newValue;
        }

        return widget.builder(context, _selectedValue, widget.child);
      },
    );
  }
}
