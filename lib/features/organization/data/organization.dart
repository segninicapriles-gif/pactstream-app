/// Modelos del feature Organizations (Sprint 6).
///
/// Una organización es la empresa que agrupa a uno o más miembros.
/// Cada user puede ser owner máximo de UNA organización y miembro de varias.
///
/// Mapean al payload de:
///   - `sf_list_my_orgs()` (cuerpo `organizations[]`)
///   - `sf_get_org_members(p_org_id)` (cuerpo `members[]`)

class Organization {
  Organization({
    required this.id,
    required this.legalName,
    required this.orgType,
    required this.isOwner,
    required this.canViewEconomics,
    required this.memberId,
    required this.membersCount,
    required this.pendingInvitesCount,
    this.tradeName,
    this.cif,
    this.description,
    this.kybStatus,
    this.joinedAt,
  });

  final String id;
  /// Nombre legal de la empresa (de la tabla `organizations.legal_name`).
  final String legalName;
  final String? tradeName;
  final String? cif;
  final String? description;
  /// 'constructor' | 'tecnico' | 'promotor' | 'mixed'
  final String orgType;
  /// Estado KYB de la empresa (Onfido / Veriff). Null hasta que se inicia.
  final String? kybStatus;

  // === Relación con el user actual ===
  /// `true` si el user del contexto auth es el owner de esta organización.
  final bool isOwner;
  /// `true` si el user tiene permiso para ver datos económicos.
  final bool canViewEconomics;
  /// ID de la fila `organization_members` que representa al user en esta org.
  final String memberId;
  /// Cuándo se unió el user a esta organización (puede ser null para el owner
  /// que se vinculó manualmente desde BD en migración).
  final DateTime? joinedAt;

  // === Estadísticas ===
  final int membersCount;
  final int pendingInvitesCount;

  String get displayName => tradeName ?? legalName;

  factory Organization.fromJson(Map<String, dynamic> j) {
    return Organization(
      id: j['id'] as String,
      legalName: j['legal_name'] as String,
      tradeName: j['trade_name'] as String?,
      cif: j['cif'] as String?,
      description: j['description'] as String?,
      orgType: (j['org_type'] as String?) ?? 'constructor',
      kybStatus: j['kyb_status'] as String?,
      isOwner: (j['is_owner'] as bool?) ?? false,
      canViewEconomics: (j['can_view_economics'] as bool?) ?? false,
      memberId: j['member_id'] as String,
      joinedAt: j['joined_at'] != null
          ? DateTime.parse(j['joined_at'] as String)
          : null,
      membersCount: ((j['members_count'] as num?) ?? 0).toInt(),
      pendingInvitesCount: ((j['pending_invites_count'] as num?) ?? 0).toInt(),
    );
  }
}

/// Un miembro de una organización.
class OrganizationMember {
  OrganizationMember({
    required this.id,
    required this.email,
    required this.role,
    required this.state,
    required this.canViewEconomics,
    required this.invitedAt,
    required this.isMe,
    this.userId,
    this.fullName,
    this.acceptedAt,
    this.revokedAt,
  });

  final String id;
  /// User vinculado (null mientras la invitación está en `invited`).
  final String? userId;
  final String email;
  final String? fullName;
  /// 'owner' | 'member'
  final String role;
  /// 'invited' | 'active' | 'revoked'
  final String state;
  final bool canViewEconomics;
  final DateTime invitedAt;
  final DateTime? acceptedAt;
  final DateTime? revokedAt;
  /// `true` si este miembro es el user autenticado.
  final bool isMe;

  bool get isOwner => role == 'owner';
  bool get isActive => state == 'active';
  bool get isPending => state == 'invited';
  bool get isRevoked => state == 'revoked';

  String get displayName =>
      (fullName?.trim().isNotEmpty ?? false) ? fullName! : email;

  factory OrganizationMember.fromJson(Map<String, dynamic> j) {
    return OrganizationMember(
      id: j['id'] as String,
      userId: j['user_id'] as String?,
      email: j['email'] as String,
      fullName: j['full_name'] as String?,
      role: (j['role'] as String?) ?? 'member',
      state: (j['state'] as String?) ?? 'invited',
      canViewEconomics: (j['can_view_economics'] as bool?) ?? false,
      invitedAt: DateTime.parse(j['invited_at'] as String),
      acceptedAt: j['accepted_at'] != null
          ? DateTime.parse(j['accepted_at'] as String)
          : null,
      revokedAt: j['revoked_at'] != null
          ? DateTime.parse(j['revoked_at'] as String)
          : null,
      isMe: (j['is_me'] as bool?) ?? false,
    );
  }
}

/// Wrapper del resultado de `sf_get_org_members()`.
class OrgMembersResult {
  OrgMembersResult({
    required this.organizationId,
    required this.isOwnerView,
    required this.members,
  });

  final String organizationId;
  /// `true` si el caller es el owner (ve también miembros revocados).
  final bool isOwnerView;
  final List<OrganizationMember> members;

  /// Miembros activos.
  List<OrganizationMember> get active =>
      members.where((m) => m.isActive).toList();

  /// Invitaciones pendientes.
  List<OrganizationMember> get pending =>
      members.where((m) => m.isPending).toList();

  /// Miembros revocados (solo visibles para owner).
  List<OrganizationMember> get revoked =>
      members.where((m) => m.isRevoked).toList();

  factory OrgMembersResult.fromJson(Map<String, dynamic> j) {
    return OrgMembersResult(
      organizationId: j['organization_id'] as String,
      isOwnerView: (j['is_owner_view'] as bool?) ?? false,
      members: (j['members'] as List<dynamic>? ?? const [])
          .map((e) => OrganizationMember.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
