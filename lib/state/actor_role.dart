/// Who is attempting a state transition.
///
/// This is the state machine's own abstraction — it is deliberately decoupled
/// from app-specific role enums like `StaffRole` so that the machine can live
/// in `fastcorr_shared` without depending on any app. Each app is responsible
/// for mapping its own user role into an [ActorRole] before calling the
/// machine (e.g. admin app maps `StaffRole.office_admin` → `ActorRole.officeAdmin`).
///
/// Add new roles here only if they need distinct permissions in the
/// transition table. If two roles always share identical permissions, collapse
/// them before adding to this enum.
enum ActorRole {
  /// End-user / law-firm lawyer creating and owning requests in the user app.
  lawyer,

  /// Secretary in the admin app — claims, works, and marks ready-for-pickup
  /// on litigation requests.
  secretary,

  /// Court correspondent in the admin app. Currently treated the same as
  /// secretary for state transitions; split out so permissions can diverge.
  correspondent,

  /// Delivery coordinator in the admin app. Oversees messenger orders but
  /// does not self-claim litigation work.
  deliveryCoordinator,

  /// Office-level admin — the "manager" of a firm's office. Can assign and
  /// cancel requests within their office.
  officeAdmin,

  /// Company-wide super admin. Can escalate and override anywhere.
  superAdmin,

  /// Driver in the driver app — picks up and delivers.
  driver,

  /// Automated actor for Cloud Functions / timers / system escalations.
  /// Only `system` can write `Status.overdue` and auto-escalations.
  system,
}
