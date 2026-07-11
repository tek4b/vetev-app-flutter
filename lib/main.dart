import 'package:flutter/material.dart';

void main() {
  runApp(
    const MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.blue,
        body: Center(
          child: Text(
            'TESTE OK',
            style: TextStyle(color: Colors.white, fontSize: 32),
          ),
        ),
      ),
    ),
  );
}
