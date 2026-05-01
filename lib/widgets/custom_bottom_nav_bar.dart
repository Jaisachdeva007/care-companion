import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/edit_health_info_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/emergency_services_screen.dart';
import '../screens/home_screen.dart';
import '../screens/link_senior_screen.dart';
import '../services/firestore_service.dart';

enum AppTab {
  services,
  home,
  health,
  profile,
  seniors,
}

class CustomBottomNavBar extends StatelessWidget {
  final AppTab currentTab;

  const CustomBottomNavBar({
    super.key,
    required this.currentTab,
  });

  void _replaceScreen(
    BuildContext context,
    Widget screen, {
    required Offset beginOffset,
  }) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );

          final slideAnimation = Tween<Offset>(
            begin: beginOffset,
            end: Offset.zero,
          ).animate(curved);

          final fadeAnimation = Tween<double>(
            begin: 0.88,
            end: 1.0,
          ).animate(curved);

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: child,
            ),
          );
        },
      ),
    );
  }

  Offset _getSlideDirection(AppTab targetTab) {
    const tabOrder = {
      AppTab.services: 0,
      AppTab.home: 1,
      AppTab.health: 2,
      AppTab.profile: 3,
      AppTab.seniors: 2,
    };

    final currentIndex = tabOrder[currentTab] ?? 0;
    final targetIndex = tabOrder[targetTab] ?? 0;

    if (targetIndex > currentIndex) {
      return const Offset(0.08, 0);
    } else {
      return const Offset(-0.08, 0);
    }
  }

  Future<void> _handleCenterAction(
    BuildContext context, {
    required String uid,
    required bool isCaregiver,
    required List<String> linkedCaregiverUids,
  }) async {
    if (isCaregiver) {
      _replaceScreen(
        context,
        const LinkSeniorScreen(),
        beginOffset: const Offset(0, 0.08),
      );
      return;
    }

    if (linkedCaregiverUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please link a caregiver first.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Send alert?'),
          content: const Text(
            'Your caregiver(s) will be notified immediately to check on you.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Send Alert'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final result = await FirestoreService().createCheckOnMeAlert(
        seniorUid: uid,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send alert: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder(
      stream: FirestoreService().getUserStream(uid),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() ?? <String, dynamic>{};
        final role = (userData['role'] ?? 'senior').toString();
        final isCaregiver = role == 'caregiver';

        final linkedCaregiverUids = <String>{
          ...List<String>.from(userData['linkedCaregiverUids'] ?? []),
          if ((userData['linkedCaregiverUid'] ?? '')
              .toString()
              .trim()
              .isNotEmpty)
            (userData['linkedCaregiverUid'] ?? '').toString().trim(),
        }.toList();

        final items = isCaregiver
            ? const [
                _NavItem(
                  tab: AppTab.services,
                  icon: Icons.location_on_outlined,
                  activeIcon: Icons.location_on,
                  label: 'Services',
                ),
                _NavItem(
                  tab: AppTab.home,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                ),
                _NavItem(
                  tab: AppTab.seniors,
                  icon: Icons.people_alt_outlined,
                  activeIcon: Icons.people_alt_rounded,
                  label: 'Seniors',
                ),
                _NavItem(
                  tab: AppTab.profile,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                ),
              ]
            : const [
                _NavItem(
                  tab: AppTab.services,
                  icon: Icons.location_on_outlined,
                  activeIcon: Icons.location_on,
                  label: 'Services',
                ),
                _NavItem(
                  tab: AppTab.home,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                ),
                _NavItem(
                  tab: AppTab.health,
                  icon: Icons.health_and_safety_outlined,
                  activeIcon: Icons.health_and_safety,
                  label: 'Health',
                ),
                _NavItem(
                  tab: AppTab.profile,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                ),
              ];

        void goToTab(AppTab tab) {
          if (tab == currentTab) return;

          final slideOffset = _getSlideDirection(tab);

          if (isCaregiver) {
            switch (tab) {
              case AppTab.services:
                _replaceScreen(
                  context,
                  const EmergencyServicesScreen(),
                  beginOffset: slideOffset,
                );
                break;
              case AppTab.home:
                _replaceScreen(
                  context,
                  const HomeScreen(),
                  beginOffset: slideOffset,
                );
                break;
              case AppTab.seniors:
                _replaceScreen(
                  context,
                  const LinkSeniorScreen(),
                  beginOffset: slideOffset,
                );
                break;
              case AppTab.profile:
                _replaceScreen(
                  context,
                  const EditProfileScreen(),
                  beginOffset: slideOffset,
                );
                break;
              case AppTab.health:
                _replaceScreen(
                  context,
                  const HomeScreen(),
                  beginOffset: slideOffset,
                );
                break;
            }
          } else {
            switch (tab) {
              case AppTab.services:
                _replaceScreen(
                  context,
                  const EmergencyServicesScreen(),
                  beginOffset: slideOffset,
                );
                break;
              case AppTab.home:
                _replaceScreen(
                  context,
                  const HomeScreen(),
                  beginOffset: slideOffset,
                );
                break;
              case AppTab.health:
                _replaceScreen(
                  context,
                  const EditHealthInfoScreen(),
                  beginOffset: slideOffset,
                );
                break;
              case AppTab.profile:
                _replaceScreen(
                  context,
                  const EditProfileScreen(),
                  beginOffset: slideOffset,
                );
                break;
              case AppTab.seniors:
                _replaceScreen(
                  context,
                  const HomeScreen(),
                  beginOffset: slideOffset,
                );
                break;
            }
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            height: 96,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 78,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x16000000),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _NavButton(
                            item: items[0],
                            isSelected: currentTab == items[0].tab,
                            onTap: () => goToTab(items[0].tab),
                          ),
                        ),
                        Expanded(
                          child: _NavButton(
                            item: items[1],
                            isSelected: currentTab == items[1].tab,
                            onTap: () => goToTab(items[1].tab),
                          ),
                        ),
                        const SizedBox(width: 76),
                        Expanded(
                          child: _NavButton(
                            item: items[2],
                            isSelected: currentTab == items[2].tab,
                            onTap: () => goToTab(items[2].tab),
                          ),
                        ),
                        Expanded(
                          child: _NavButton(
                            item: items[3],
                            isSelected: currentTab == items[3].tab,
                            onTap: () => goToTab(items[3].tab),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  child: GestureDetector(
                    onTap: () => _handleCenterAction(
                      context,
                      uid: uid,
                      isCaregiver: isCaregiver,
                      linkedCaregiverUids: linkedCaregiverUids,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          height: 54,
                          width: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF4FF),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFD6E6FF),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            isCaregiver
                                ? Icons.add_link_rounded
                                : Icons.notifications_active_rounded,
                            color: const Color(0xFF2354B8),
                            size: 25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isCaregiver ? 'Link' : 'SOS',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2354B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavItem {
  final AppTab tab;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.tab,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF2354B8);
    final inactiveColor = const Color(0xFF9CA3AF);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF4FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: isSelected
              ? Border.all(color: const Color(0xFFD6E6FF))
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              scale: isSelected ? 1.06 : 1.0,
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                color: isSelected ? activeColor : inactiveColor,
                size: isSelected ? 25 : 22,
              ),
            ),
            const SizedBox(height: 3),
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                style: TextStyle(
                  fontSize: isSelected ? 12.5 : 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}