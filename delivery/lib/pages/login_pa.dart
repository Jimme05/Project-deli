import 'package:delivery/pages/login_page.dart';
import 'package:delivery/pages/rider_login.dart';
import 'package:flutter/material.dart';
import '../widgets/app_logo.dart';


class LoginPa extends StatefulWidget {
  const LoginPa({super.key});
  @override
  State<LoginPa> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<LoginPa> with TickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
          const SizedBox(height: 6),
          Expanded(
            child: TabBarView(controller: _tab, children: const [
              LoginPage(),
              LoginPageRider(),
            ]),
          ),
        ]),
      ),
    );
  }
}
