import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../view_models/auth_view_model.dart';

// 홈·영화·마이페이지 탭의 공통 틀입니다. NavigationBar는 여기서 한 번만 만들고 body만 바뀝니다.
// 탭을 바꿔도 이 State는 유지되므로, 어느 탭으로 들어오든 내 정보를 한 번만 불러옵니다.
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
  static const _tabPaths = ['/home', '/movies', '/my'];

  @override
  void initState() {
    super.initState();
    // loadMember()는 바로 notifyListeners()를 부르므로 첫 build가 끝난 뒤 호출합니다.
    // 앱 재시작으로 복원된 경우에는 이미 member가 있어 다시 요청하지 않습니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthViewModel>().loadMember();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.currentIndex,
        onDestinationSelected: (index) => context.go(_tabPaths[index]),
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
    );
  }
}
