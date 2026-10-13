import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/features/recurring/buchungsvorlagen_repository.dart';
import 'package:openaccounting/features/recurring/recurring_booking_workspace_usecases.dart';

/// Riverpod seam for the canonical `/recurring` workspace. The page resolves
/// the use case here (or via `AppScope.services.recurringBooking`) and never
/// issues direct SQL writes itself.
final recurringBookingUseCasesProvider = Provider<RecurringBookingWorkspaceUseCases>((ref) {
  final AppServices services = ref.watch(appServicesProvider);
  return services.recurringBooking;
});

final recurringTemplatesProvider = FutureProvider<List<BuchungsVorlage>>((ref) async {
  return ref.watch(recurringBookingUseCasesProvider).listTemplates();
});

final recurringDueInstancesProvider = FutureProvider<List<DueInstanceView>>((ref) async {
  return ref.watch(recurringBookingUseCasesProvider).refreshDueInstances();
});
