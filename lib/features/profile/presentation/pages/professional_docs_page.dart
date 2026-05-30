import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../data/datasources/supabase/supabase_client.dart';

/// Required/recommended document types per role, based on Spanish law.
class _DocType {
  const _DocType({
    required this.id,
    required this.label,
    required this.sublabel,
    required this.required,
    this.legalRef,
  });

  final String id;
  final String label;
  final String sublabel;
  final bool required;
  final String? legalRef;
}

const _tecnicoDocs = <_DocType>[
  _DocType(
    id: 'titulo_universitario',
    label: 'Titulo universitario habilitante',
    sublabel: 'Grado en Arquitectura / Ingenieria de Edificacion',
    required: true,
    legalRef: 'LOE art. 10, 13',
  ),
  _DocType(
    id: 'colegiacion',
    label: 'Certificado de colegiacion vigente',
    sublabel: 'Del Colegio Profesional de tu provincia',
    required: true,
    legalRef: 'Ley 2/1974',
  ),
  _DocType(
    id: 'seguro_rc',
    label: 'Seguro de Responsabilidad Civil profesional',
    sublabel: 'Poliza vigente que cubra errores y omisiones',
    required: true,
    legalRef: 'LOE art. 17 + Ley 2/1974 art. 5.i',
  ),
  _DocType(
    id: 'visado_colegial',
    label: 'Visado colegial',
    sublabel: 'Obligatorio para proyectos de ejecucion y certificados finales',
    required: false,
    legalRef: 'RD 1000/2010',
  ),
];

const _constructorDocs = <_DocType>[
  _DocType(
    id: 'nif_escritura',
    label: 'NIF + Escritura de constitucion',
    sublabel: 'NIF de la sociedad e inscripcion en Registro Mercantil',
    required: true,
    legalRef: 'Ley General Tributaria',
  ),
  _DocType(
    id: 'alta_iae',
    label: 'Alta en el IAE',
    sublabel: 'Epigrafe del grupo 50 (construccion)',
    required: true,
    legalRef: 'RDL 1175/1990',
  ),
  _DocType(
    id: 'rea',
    label: 'Inscripcion REA',
    sublabel: 'Registro de Empresas Acreditadas (valido 3 anos)',
    required: true,
    legalRef: 'Ley 32/2006 art. 4',
  ),
  _DocType(
    id: 'seguridad_social',
    label: 'Certificado Seguridad Social',
    sublabel: 'Al corriente de obligaciones con la Seguridad Social',
    required: true,
    legalRef: 'RDL 8/2015',
  ),
  _DocType(
    id: 'hacienda',
    label: 'Certificado Hacienda (AEAT)',
    sublabel: 'Al corriente de obligaciones tributarias',
    required: true,
    legalRef: 'Ley General Tributaria',
  ),
  _DocType(
    id: 'seguro_rc',
    label: 'Seguro de Responsabilidad Civil',
    sublabel: 'Cobertura por defectos de construccion (LOE)',
    required: true,
    legalRef: 'LOE art. 19',
  ),
  _DocType(
    id: 'prl',
    label: 'Plan de Prevencion de Riesgos Laborales',
    sublabel: 'Incluyendo organizacion preventiva y formacion',
    required: true,
    legalRef: 'Ley 31/1995 + RD 39/1997',
  ),
  _DocType(
    id: 'iso_certificaciones',
    label: 'Certificaciones ISO',
    sublabel: 'ISO 9001, 14001, 45001 (si disponible)',
    required: false,
  ),
];

/// Page to upload professional/company documents per role.
class ProfessionalDocsPage extends ConsumerStatefulWidget {
  const ProfessionalDocsPage({super.key, required this.role});

  final String role;

  @override
  ConsumerState<ProfessionalDocsPage> createState() =>
      _ProfessionalDocsPageState();
}

class _ProfessionalDocsPageState extends ConsumerState<ProfessionalDocsPage> {
  final Map<String, _UploadedDoc> _uploadedDocs = {};
  bool _loading = true;

  List<_DocType> get _docTypes =>
      widget.role == 'tecnico' ? _tecnicoDocs : _constructorDocs;

  @override
  void initState() {
    super.initState();
    _loadExistingDocs();
  }

  Future<void> _loadExistingDocs() async {
    try {
      final rows = await SupabaseConfig.client
          .from('user_professional_docs')
          .select()
          .eq('user_id', SupabaseConfig.currentUser!.id)
          .order('uploaded_at', ascending: false);

      if (!mounted) return;
      for (final row in rows) {
        final docType = row['doc_type'] as String;
        _uploadedDocs[docType] = _UploadedDoc(
          fileName: row['file_name'] as String,
          uploadedAt: DateTime.parse(row['uploaded_at'] as String),
          url: row['file_url'] as String?,
        );
      }
    } catch (_) {
      // Table may not exist yet — that's OK, we'll handle uploads gracefully
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUpload(_DocType docType) async {
    // Use image_picker which works reliably on web and mobile
    final picker = ImagePicker();
    final XFile? picked;

    // Show a dialog to choose between camera image or gallery
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subir: ${docType.label}',
                style: AppTypography.h3.copyWith(color: ctx.colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                docType.sublabel,
                style: AppTypography.bodyS.copyWith(color: ctx.colors.textTertiary),
              ),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: ctx.colors.brandAccent),
                title: const Text('Seleccionar imagen del documento'),
                subtitle: Text('JPG, PNG', style: AppTypography.caption.copyWith(color: ctx.colors.textTertiary)),
                onTap: () => Navigator.pop(ctx, 'gallery'),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: ctx.colors.brandAccent),
                title: const Text('Hacer foto al documento'),
                subtitle: Text('Captura directa', style: AppTypography.caption.copyWith(color: ctx.colors.textTertiary)),
                onTap: () => Navigator.pop(ctx, 'camera'),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      picked = await picker.pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo acceder a los archivos: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final fileName = picked.name;

    AppHaptics.medium();
    setState(() {
      _uploadedDocs[docType.id] = _UploadedDoc(
        fileName: fileName,
        uploadedAt: DateTime.now(),
        uploading: true,
      );
    });

    try {
      final uid = SupabaseConfig.currentUser!.id;
      final ext = fileName.split('.').last.toLowerCase();
      final path = '$uid/docs/${docType.id}.$ext';

      // Upload to Supabase Storage
      await SupabaseConfig.client.storage
          .from('professional-docs')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: ext == 'pdf' ? 'application/pdf' : 'image/$ext',
              upsert: true,
            ),
          );

      final url = SupabaseConfig.client.storage
          .from('professional-docs')
          .getPublicUrl(path);

      // Try to record in DB (may fail if table doesn't exist yet)
      try {
        await SupabaseConfig.client.from('user_professional_docs').upsert({
          'user_id': uid,
          'doc_type': docType.id,
          'file_name': fileName,
          'file_url': url,
          'uploaded_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,doc_type');
      } catch (_) {
        // DB table may not exist — upload to storage still succeeded
      }

      if (!mounted) return;
      AppHaptics.success();
      setState(() {
        _uploadedDocs[docType.id] = _UploadedDoc(
          fileName: fileName,
          uploadedAt: DateTime.now(),
          url: url,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.white, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('${docType.label} subido correctamente')),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppHaptics.warning();
      setState(() {
        _uploadedDocs.remove(docType.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isTecnico = widget.role == 'tecnico';
    final uploadedCount =
        _docTypes.where((d) => _uploadedDocs.containsKey(d.id)).length;
    final requiredCount = _docTypes.where((d) => d.required).length;
    final requiredUploaded = _docTypes
        .where((d) => d.required && _uploadedDocs.containsKey(d.id))
        .length;

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.psGradientDeep),
        ),
        title: Text(
          isTecnico ? 'Documentacion profesional' : 'Documentacion de empresa',
          style: AppTypography.h3.copyWith(color: AppColors.white),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                // Progress header
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: AppRadius.lgAll,
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            requiredUploaded == requiredCount
                                ? Icons.verified_outlined
                                : Icons.info_outline,
                            color: requiredUploaded == requiredCount
                                ? AppColors.success
                                : c.brandAccent,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              requiredUploaded == requiredCount
                                  ? 'Documentacion completa'
                                  : '$requiredUploaded de $requiredCount obligatorios subidos',
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '$uploadedCount/${_docTypes.length}',
                            style: AppTypography.bodyS.copyWith(
                              color: c.textTertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: AppRadius.xxsAll,
                        child: LinearProgressIndicator(
                          value: _docTypes.isEmpty
                              ? 0
                              : uploadedCount / _docTypes.length,
                          minHeight: 6,
                          backgroundColor: c.border,
                          valueColor: AlwaysStoppedAnimation(
                            requiredUploaded == requiredCount
                                ? AppColors.success
                                : AppColors.psBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Legal notice
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: c.infoBg,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.gavel_outlined,
                          size: 16, color: c.brandAccent),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          isTecnico
                              ? 'Documentacion requerida segun LOE (Ley 38/1999) y Ley de Colegios Profesionales (Ley 2/1974).'
                              : 'Documentacion requerida segun LOE (Ley 38/1999), Ley de Subcontratacion (Ley 32/2006) y normativa PRL.',
                          style: AppTypography.caption.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Required section
                Text(
                  'OBLIGATORIO',
                  style: AppTypography.caption.copyWith(
                    color: c.textTertiary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ..._docTypes.where((d) => d.required).map(
                      (d) => _DocUploadCard(
                        docType: d,
                        uploaded: _uploadedDocs[d.id],
                        onUpload: () => _pickAndUpload(d),
                      ),
                    ),

                // Optional section
                if (_docTypes.any((d) => !d.required)) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'RECOMENDADO',
                    style: AppTypography.caption.copyWith(
                      color: c.textTertiary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ..._docTypes.where((d) => !d.required).map(
                        (d) => _DocUploadCard(
                          docType: d,
                          uploaded: _uploadedDocs[d.id],
                          onUpload: () => _pickAndUpload(d),
                        ),
                      ),
                ],

                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
    );
  }
}

class _UploadedDoc {
  const _UploadedDoc({
    required this.fileName,
    required this.uploadedAt,
    this.url,
    this.uploading = false,
  });

  final String fileName;
  final DateTime uploadedAt;
  final String? url;
  final bool uploading;
}

class _DocUploadCard extends StatelessWidget {
  const _DocUploadCard({
    required this.docType,
    this.uploaded,
    required this.onUpload,
  });

  final _DocType docType;
  final _UploadedDoc? uploaded;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isUploaded = uploaded != null && !uploaded!.uploading;
    final isUploading = uploaded?.uploading ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: isUploaded
                ? AppColors.success.withValues(alpha: 0.4)
                : c.border,
          ),
        ),
        child: InkWell(
          onTap: isUploading ? null : onUpload,
          borderRadius: AppRadius.mdAll,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isUploaded
                        ? AppColors.success.withValues(alpha: 0.1)
                        : isUploading
                            ? c.infoBg
                            : (docType.required
                                ? AppColors.warning.withValues(alpha: 0.1)
                                : c.chipBg),
                    shape: BoxShape.circle,
                  ),
                  child: isUploading
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isUploaded
                              ? Icons.check_circle_rounded
                              : (docType.required
                                  ? Icons.warning_amber_rounded
                                  : Icons.description_outlined),
                          size: 18,
                          color: isUploaded
                              ? AppColors.success
                              : (docType.required
                                  ? AppColors.warning
                                  : c.textTertiary),
                        ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        docType.label,
                        style: AppTypography.bodyS.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        docType.sublabel,
                        style: AppTypography.caption.copyWith(
                          color: c.textTertiary,
                        ),
                      ),
                      if (docType.legalRef != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          docType.legalRef!,
                          style: AppTypography.caption.copyWith(
                            color: c.brandAccent,
                            fontSize: 10,
                          ),
                        ),
                      ],
                      if (isUploaded) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Icon(Icons.attach_file,
                                size: 12, color: AppColors.success),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                uploaded!.fileName,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),

                // Upload button
                Icon(
                  isUploaded ? Icons.swap_horiz : Icons.upload_outlined,
                  color: isUploaded ? AppColors.success : c.brandAccent,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
