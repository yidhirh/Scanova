// widgets/patient_info_card.dart
//
// Carte d'identité patient — utilisée en tête du dossier patient.
// Avatar avec initiales, nom complet, ID, lignes d'infos.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PatientInfoCard extends StatelessWidget {
  final String fullName;
  final String? patientId;
  final List<PatientInfoRow> rows;

  const PatientInfoCard({
    super.key,
    required this.fullName,
    this.patientId,
    this.rows = const [],
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final a = parts.first[0];
    final b = parts.length > 1 ? parts[1][0] : '';
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        boxShadow: AppShadows.elev,
      ),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(
              color: Color(0x1F2563EB), shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(fullName),
              style: const TextStyle(
                color: AppColors.brand600,
                fontWeight: FontWeight.w700,
                fontSize: 24,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink900,
            ),
          ),
          if (patientId != null) ...[
            const SizedBox(height: 2),
            Text(
              patientId!,
              style: const TextStyle(
                fontSize: 12, color: AppColors.ink400,
                letterSpacing: 0.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.ink200),
            const SizedBox(height: 10),
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(r.icon, size: 18, color: AppColors.brand600),
                      const SizedBox(width: 10),
                      Text('${r.label} : ', style: const TextStyle(fontSize: 14, color: AppColors.ink500)),
                      Expanded(
                        child: Text(
                          r.value,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink900,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class PatientInfoRow {
  final IconData icon;
  final String label;
  final String value;
  const PatientInfoRow({required this.icon, required this.label, required this.value});
}
