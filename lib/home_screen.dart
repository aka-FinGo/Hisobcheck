import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Any initial resource allocation
  }

  @override
  void dispose() {
    // Cleanup resources if needed
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });
    // Simulating a network call
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        _isLoading = false;
        // Mock error handling for demo
        _errorMessage = 'An error occurred!';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeData>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Home Screen', style: theme.textTheme.headline6),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            if (_isLoading)
              CircularProgressIndicator(),
            if (_errorMessage != null)
              Text(_errorMessage!, style: TextStyle(color: Colors.red)),
            Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Enter Value'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a value';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text('Submit'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}