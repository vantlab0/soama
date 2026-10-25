import 'package:flutter/material.dart';

class ServiceCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String imageUrl;
  final int providerCount;

  const ServiceCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.imageUrl,
    required this.providerCount,
  });

  static const List<ServiceCategory> mockCategories = [
    ServiceCategory(
      id: 'cleaning',
      title: 'Cleaning',
      subtitle: 'Homes, offices & post-construction',
      icon: Icons.cleaning_services_outlined,
      imageUrl: 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=600&q=80',
      providerCount: 42,
    ),
    ServiceCategory(
      id: 'plumbing',
      title: 'Plumbing',
      subtitle: 'Leaks, boreholes & sanitary fittings',
      icon: Icons.plumbing_outlined,
      imageUrl: 'https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?auto=format&fit=crop&w=600&q=80',
      providerCount: 36,
    ),
    ServiceCategory(
      id: 'electrical',
      title: 'Electrical',
      subtitle: 'Wiring, inverters & solar systems',
      icon: Icons.bolt_outlined,
      imageUrl: 'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?auto=format&fit=crop&w=600&q=80',
      providerCount: 48,
    ),
    ServiceCategory(
      id: 'repairs',
      title: 'Repairs',
      subtitle: 'Generators, ACs & appliances',
      icon: Icons.handyman_outlined,
      imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=600&q=80',
      providerCount: 55,
    ),
    ServiceCategory(
      id: 'moving',
      title: 'Moving',
      subtitle: 'Relocation & heavy haulage',
      icon: Icons.local_shipping_outlined,
      imageUrl: 'https://images.unsplash.com/photo-1600518464441-9154a4dea21b?auto=format&fit=crop&w=600&q=80',
      providerCount: 24,
    ),
    ServiceCategory(
      id: 'beauty',
      title: 'Beauty',
      subtitle: 'Hair stylists, barbers & makeup',
      icon: Icons.spa_outlined,
      imageUrl: 'https://images.unsplash.com/photo-1560066984-138dadb4c035?auto=format&fit=crop&w=600&q=80',
      providerCount: 38,
    ),
  ];
}
