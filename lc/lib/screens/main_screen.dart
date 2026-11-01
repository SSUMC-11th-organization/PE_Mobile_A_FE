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
    // 홈 탭(index 0)에서만 뒤로 가기가 동작하지 않는다.
    return PopScope(
      canPop: currentIndex != 0,
      child: Scaffold(
        body: child,
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                offset: Offset(0, -4),
                blurRadius: 20,
                spreadRadius: -10,
              ),
            ],
          ),
          child: NavigationBar(
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
      ),
    );
  }
}
