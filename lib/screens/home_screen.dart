// Updated home_screen.dart file

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Home Screen', style: TextStyle(color: themeProvider.textColor)),
        backgroundColor: themeProvider.backgroundColor,
      ),
      body: Center(
        child: Text(
          'Welcome to Home Screen!',
          style: TextStyle(color: themeProvider.textColor),
        ),
      ),
    );
  }
}