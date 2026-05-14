// DEPRECATED · Modelo v2.0
//
// El wizard de creación de pacto v2.0 tiene solo 4 pasos
// (básicos, presupuesto+depósito, equipo, resumen) y ya no incluye un
// paso de "vista previa" separado — el resumen se muestra dentro de
// NewPactStepConfirm.
//
// Este archivo se conserva como stub vacío para no romper compilación
// de imports antiguos. Se eliminará en un sprint posterior.

import 'package:flutter/material.dart';

import '../../data/pact_creation_data.dart';

@Deprecated('El paso Preview se fusionó con NewPactStepConfirm en el modelo v2.0')
class NewPactStepPreview extends StatelessWidget {
  const NewPactStepPreview({super.key, required this.data});

  final PactCreationData data;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
