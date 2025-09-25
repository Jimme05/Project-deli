import 'package:flutter/material.dart';
import '../widgets/app_logo.dart';
import 'register_user_page.dart';
import 'register_rider_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with TickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text("Register"),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: "User"), Tab(text: "Rider")],
        ),
      ),
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 10),
          const AppLogo(),
          const SizedBox(height: 6),
          Expanded(
            child: TabBarView(controller: _tab, children: const [
              RegisterUserTab(),
              RegisterRiderTab(),
            ]),
          ),
        ]),
      ),
    );
  }
}
