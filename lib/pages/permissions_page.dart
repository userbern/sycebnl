import 'package:flutter/material.dart';

class PermissionsPage extends StatefulWidget {
	const PermissionsPage({super.key});

	@override
	State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
	@override
	Widget build(BuildContext context) {
		return const Scaffold(
			body: Center(
				child: Text('Permissions Page'),
			),
		);
	}
}
