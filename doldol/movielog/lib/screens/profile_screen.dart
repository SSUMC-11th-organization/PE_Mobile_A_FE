import 'package:flutter/material.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/profile_header.dart';
import '../widgets/stat_item.dart';
import '../widgets/favorite_genres.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: '내 프로필'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: const [
              ProfileHeader(),
              SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: StatItem(label: '본 영화', value: '342')),
                  SizedBox(width: 8),
                  Expanded(child: StatItem(label: '평점', value: '4.2')),
                  SizedBox(width: 8),
                  Expanded(child: StatItem(label: '즐겨찾기', value: '58')),
                ],
              ),
              SizedBox(height: 24),
              SizedBox(width: double.infinity, child: FavoriteGenres()),
            ],
          ),
        ),
      ),
    );
  }
}