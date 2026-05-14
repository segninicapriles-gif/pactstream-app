import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/pact_providers.dart';

/// Pantalla de subida de evidencia para un hito en curso.
///
/// Flujo:
///   1. Usuario elige Cámara o Galería.
///   2. Selecciona/captura la imagen → preview.
///   3. (Opcional) Adjunta descripción y captura GPS.
///   4. Confirma → uploader sube a Storage + RPC registra en BD.
///   5. Vuelve al detalle del hito con la evidencia añadida.
class UploadEvidencePage extends ConsumerStatefulWidget {
  const UploadEvidencePage({
    super.key,
    required this.pactId,
    required this.milestoneId,
  });

  final String pactId;
  final String milestoneId;

  @override
  ConsumerState<UploadEvidencePage> createState() =>
      _UploadEvidencePageState();
}

class _UploadEvidencePageState extends ConsumerState<UploadEvidencePage> {
  final _picker = ImagePicker();
  final _descriptionCtrl = TextEditingController();

  XFile? _picked;
  Uint8List? _bytes;
  Position? _gps;
  bool _gpsLoading = false;
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _error = null);
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2400,
        maxHeight: 2400,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _picked = picked;
        _bytes = bytes;
      });
      // Capturamos GPS automáticamente si la foto es nueva (cámara).
      if (source == ImageSource.camera) {
        _captureGps();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo leer la imagen: $e');
    }
  }

  Future<void> _captureGps() async {
    setState(() => _gpsLoading = true);
    try {
      // Verificar permisos
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('GPS desactivado en el dispositivo.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        throw Exception('Permiso de ubicación denegado.');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      setState(() => _gps = pos);
    } catch (e) {
      // GPS no es bloqueante. Si falla, registramos evidencia sin GPS.
      debugPrint('GPS error: $e');
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  Future<void> _confirmUpload() async {
    if (_bytes == null || _picked == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final uploader = ref.read(evidenceUploaderProvider);
      final repo = ref.read(pactsRepositoryProvider);

      // 1. Sube a Storage
      final mime = _mimeFromXFile(_picked!);
      final upload = await uploader.uploadFile(
        pactId: widget.pactId,
        milestoneId: widget.milestoneId,
        bytes: _bytes!,
        filename: _picked!.name,
        mimeType: mime,
      );

      // 2. Registra en BD
      await repo.recordMilestoneEvidence(
        milestoneId: widget.milestoneId,
        evidenceType: 'photo',
        storagePath: upload.storagePath,
        sha256Hash: upload.sha256Hash,
        fileSizeBytes: upload.sizeBytes,
        mimeType: upload.mimeType,
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        gpsLatitude: _gps?.latitude,
        gpsLongitude: _gps?.longitude,
        gpsAccuracyMeters: _gps?.accuracy,
        clientTimestamp: DateTime.now(),
      );

      // Invalidar caches
      ref.invalidate(milestoneDetailProvider(widget.milestoneId));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          content: Text('Evidencia subida correctamente',
              style: AppTypography.bodyS
                  .copyWith(color: AppColors.white)),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = e.toString();
      });
    }
  }

  String _mimeFromXFile(XFile f) {
    final n = f.name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink50,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.ink900,
        elevation: 0,
        title: Text('Subir evidencia', style: AppTypography.h3),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (_picked == null) _buildPickerOptions() else _buildPreview(),
            const SizedBox(height: AppSpacing.lg),
            if (_picked != null) ...[
              TextField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción / notas (opcional)',
                  hintText: 'Qué muestra esta evidencia, dónde, qué se ha hecho…',
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildGpsSection(),
              const SizedBox(height: AppSpacing.lg),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(_error!,
                            style: AppTypography.bodyS
                                .copyWith(color: AppColors.error)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              ElevatedButton.icon(
                icon: _uploading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                onPressed: _uploading ? null : _confirmUpload,
                label: Text(_uploading ? 'Subiendo…' : 'Subir evidencia'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _uploading
                    ? null
                    : () => setState(() {
                          _picked = null;
                          _bytes = null;
                          _gps = null;
                        }),
                child: const Text('Cambiar imagen'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPickerOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.psBlue, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Sube una foto que pruebe el avance del hito. Si capturas '
                  'desde la cámara, registramos también la ubicación GPS '
                  'como prueba forense.',
                  style: AppTypography.bodyS
                      .copyWith(color: AppColors.psNavy),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _PickerOption(
          icon: Icons.camera_alt_outlined,
          label: 'Hacer foto con la cámara',
          subtitle: 'Captura ahora · GPS automático',
          onTap: () => _pickImage(ImageSource.camera),
          primary: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        _PickerOption(
          icon: Icons.photo_library_outlined,
          label: 'Elegir de la galería',
          subtitle: 'Selecciona una foto existente',
          onTap: () => _pickImage(ImageSource.gallery),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.memory(
              _bytes!,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${_picked!.name} · ${_formatSize(_bytes!.length)}',
          style: AppTypography.caption.copyWith(
            color: AppColors.ink500,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildGpsSection() {
    if (_gpsLoading) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.ink50,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          border: Border.all(color: AppColors.ink200),
        ),
        child: Row(
          children: const [
            SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.sm),
            Text('Obteniendo ubicación GPS…'),
          ],
        ),
      );
    }
    if (_gps != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.successBg,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          border: Border.all(color: AppColors.success, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: AppColors.success, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GPS capturado',
                    style: AppTypography.bodyS.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                  Text(
                    '${_gps!.latitude.toStringAsFixed(5)}, ${_gps!.longitude.toStringAsFixed(5)}'
                    ' · precisión ${_gps!.accuracy.toStringAsFixed(0)} m',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.ink600,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return OutlinedButton.icon(
      icon: const Icon(Icons.my_location),
      onPressed: _captureGps,
      label: const Text('Capturar ubicación GPS (opcional)'),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

class _PickerOption extends StatelessWidget {
  const _PickerOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: primary ? AppColors.infoBg : AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          border: Border.all(
            color: primary ? AppColors.psBlue : AppColors.ink200,
            width: primary ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primary ? AppColors.psBlue : AppColors.ink100,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              child: Icon(icon,
                  color: primary ? AppColors.white : AppColors.ink600,
                  size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w800)),
                  Text(subtitle,
                      style: AppTypography.bodyS
                          .copyWith(color: AppColors.ink500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.ink400),
          ],
        ),
      ),
    );
  }
}
