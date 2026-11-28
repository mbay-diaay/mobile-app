import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/app_colors.dart';

/// Catalogue d’affichage espace producteur (aperçu / seed / local en attendant l’API).
class ProducerPlotInfo {
  const ProducerPlotInfo({
    required this.code,
    required this.crop,
    required this.ha,
    required this.campaign,
    required this.village,
    required this.status,
    required this.statusBg,
    required this.statusFg,
    this.declaredHa,
  });

  final String code;
  final String crop;
  final double ha;
  final String campaign;
  final String village;
  final String status;
  final Color statusBg;
  final Color statusFg;
  final double? declaredHa;

  String get haLabel => '${ha.toStringAsFixed(2).replaceAll('.', ',')} ha';
  String get declaredLabel {
    final d = declaredHa ?? ha * 1.05;
    return '${d.toStringAsFixed(2).replaceAll('.', ',')} ha';
  }
}

class ProducerEventInfo {
  const ProducerEventInfo({
    required this.title,
    required this.when,
    required this.status,
    this.plotCode,
  });

  final String title;
  final String when;

  /// done | now | soon
  final String status;
  final String? plotCode;
}

class ProducerAlertInfo {
  const ProducerAlertInfo({
    required this.icon,
    required this.title,
    required this.sub,
    required this.tint,
    required this.ink,
  });

  final IconData icon;
  final String title;
  final String sub;
  final Color tint;
  final Color ink;
}

class ProducerCatalog {
  ProducerCatalog._();

  static const plots = [
    ProducerPlotInfo(
      code: 'PA-0006',
      crop: 'Carotte, Aubergine',
      ha: 0.43,
      campaign: '2025-2026',
      village: 'Mboro',
      status: 'Relevée',
      statusBg: AppColors.blueSoft,
      statusFg: AppColors.blueInk,
    ),
    ProducerPlotInfo(
      code: 'PA-0012',
      crop: 'Oignon',
      ha: 0.28,
      campaign: '2025-2026',
      village: 'Mboro',
      status: 'Cultures OK',
      statusBg: AppColors.sage,
      statusFg: AppColors.forest,
    ),
    ProducerPlotInfo(
      code: 'PA-0018',
      crop: 'Chou',
      ha: 0.15,
      campaign: '2025-2026',
      village: 'Kayar',
      status: 'À compléter',
      statusBg: AppColors.amberIconBg,
      statusFg: AppColors.amberInk,
    ),
  ];

  static const events = [
    ProducerEventInfo(
      title: 'Semis oignon · PA-0012',
      when: '12 nov. 2025',
      status: 'done',
      plotCode: 'PA-0012',
    ),
    ProducerEventInfo(
      title: 'Traitement mildiou · PA-0012',
      when: 'Cette semaine',
      status: 'now',
      plotCode: 'PA-0012',
    ),
    ProducerEventInfo(
      title: 'Récolte chou · PA-0018',
      when: 'Début déc.',
      status: 'soon',
      plotCode: 'PA-0018',
    ),
    ProducerEventInfo(
      title: 'Assemblée SCOOP · Mboro',
      when: '28 nov. 2025',
      status: 'soon',
    ),
  ];

  static const alerts = [
    ProducerAlertInfo(
      icon: Symbols.water_drop_rounded,
      title: 'Irrigation · PA-0006',
      sub: 'Prochain passage recommandé cette semaine',
      tint: AppColors.blueSoft,
      ink: AppColors.blueInk,
    ),
    ProducerAlertInfo(
      icon: Symbols.agriculture_rounded,
      title: 'Récolte oignon approche',
      sub: 'Fenêtre estimée : début décembre',
      tint: AppColors.lime,
      ink: AppColors.forest,
    ),
    ProducerAlertInfo(
      icon: Symbols.edit_note_rounded,
      title: 'Cultures à déclarer · PA-0018',
      sub: 'Le technicien a relevé la parcelle — complétez avec votre SCOOP.',
      tint: AppColors.amberIconBg,
      ink: AppColors.amberInk,
    ),
  ];

  static double get totalHa =>
      plots.fold<double>(0, (n, p) => n + p.ha);

  static String get mainCrop => plots.isEmpty ? '—' : plots.first.crop.split(',').first.trim();
}
