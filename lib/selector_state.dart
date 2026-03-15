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
              viewModel: counterViewModel,
              selector: (viewModel) => viewModel.number1,
              // shouldRebuild: (previous, current) => previous != current,
              builder: (context, value) {
                return Container(
                  color: Colors.red,
                  padding: EdgeInsets.all(10),
                  child: Text('$value'),
                );
              },
            ),
            SizedBox(height: 8.0),
            SelectorBuilderWidget<CounterViewModel, int>(
              viewModel: counterViewModel,
              selector: (viewModel) => viewModel.number2,
              // shouldRebuild: (previous, current) => previous != current,
              builder: (context, value) {
                return Container(
                  color: Colors.green,
                  padding: EdgeInsets.all(10),
                  child: Text('$value'),
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

@protected
typedef StateSelector<T, S> = S Function(T viewModel);

@protected
typedef SelectorBuilder<S> = Widget Function(BuildContext context, S value);

class SelectorBuilderWidget<T extends ChangeNotifier, S>
    extends StatefulWidget {
  final T viewModel;
  final StateSelector<T, S> selector;
  final SelectorBuilder<S> builder;
  final bool Function(S previous, S current)? shouldRebuild;

  const SelectorBuilderWidget({
    super.key,
    required this.viewModel,
    required this.selector,
    required this.builder,
    this.shouldRebuild,
  });

  @override
  State<SelectorBuilderWidget<T, S>> createState() => _SelectorState<T, S>();
}

class _SelectorState<T extends ChangeNotifier, S>
    extends State<SelectorBuilderWidget<T, S>> {
  late S _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.selector(widget.viewModel);
  }

  @override
  void didUpdateWidget(SelectorBuilderWidget<T, S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      _selectedValue = widget.selector(widget.viewModel);
    }
  }

  bool _shouldRebuild(S previous, S current) {
    if (widget.shouldRebuild != null) {
      return widget.shouldRebuild!(previous, current);
    }
    return previous != current;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, child) {
        final newValue = widget.selector(widget.viewModel);

        if (_shouldRebuild(_selectedValue, newValue)) {
          _selectedValue = newValue;
        }

        return widget.builder(context, _selectedValue);
      },
    );
  }
}
