import 'package:flutter/material.dart';

class JournalPage extends StatelessWidget {
  final bool showAppBar;

  const JournalPage({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          showAppBar
              ? AppBar(
                title: const Text('Journal'),
                backgroundColor: Colors.blue.shade400,
                foregroundColor: Colors.white,
              )
              : null,
      body: Center(
        child: Text(
          'Journal',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade700,
          ),
        ),
      ),
    );
  }
}
