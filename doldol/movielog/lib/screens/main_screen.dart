import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  final int currentIndex;
  final Widget child;

  static const _paths = ['/home', '/movies', '/my'];

  @override
  Widget build(BuildContext context) {
    // 홈에서는 뒤로가기가 동작하지 않도록 막음
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) => context.go(_paths[index]),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.movie_outlined),
              selectedIcon: Icon(Icons.movie),
              label: '영화',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '마이',
            ),
          ],
        ),
      ),
    );
  }
}