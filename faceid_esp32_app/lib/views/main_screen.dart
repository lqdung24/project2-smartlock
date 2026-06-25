import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:faceid_esp32_app/views/devices_screen.dart'; // Tab 1 - Giờ là Home
import 'package:faceid_esp32_app/views/activity_screen.dart'; // Tab 2
import 'package:faceid_esp32_app/views/members_screen.dart';   // Tab 3
import 'package:faceid_esp32_app/views/settings_screen.dart'; // Tab 4
import 'package:faceid_esp32_app/views/widgets/bottom_nav_bar.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // Cập nhật danh sách màn hình theo thứ tự mới
  final List<Widget> _screens = [
    const HomeScreenContent(), // Đổi tên từ DevicesScreenContent
    const ActivityScreenContent(),
    const MembersScreen(),
    const SettingsScreenContent(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onNavItemTapped(int index) {
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavItemTapped,
      ),
    );
  }
}
