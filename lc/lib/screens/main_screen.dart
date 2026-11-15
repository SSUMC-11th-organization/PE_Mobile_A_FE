import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../view_models/auth_view_model.dart';

/// 홈·영화·마이 탭을 감싸는 화면. 탭을 바꿔도 유지되므로 initState는 한 번만 실행된다.
class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  final int currentIndex;
  final Widget child;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const _paths = ['/home', '/movies', '/my'];

  @override
  void initState() {
    super.initState();
    // loadMember()는 바로 notifyListeners()를 부르므로 첫 build가 끝난 뒤에 호출한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 어느 탭으로 진입하든 내 정보를 한 번 불러와 AuthViewModel.member에 보관한다.
      if (mounted) context.read<AuthViewModel>().loadMember();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 홈 탭(index 0)에서만 뒤로 가기가 동작하지 않는다.
    return PopScope(
      canPop: widget.currentIndex != 0,
      child: Scaffold(
        body: widget.child,
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
            selectedIndex: widget.currentIndex,
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
