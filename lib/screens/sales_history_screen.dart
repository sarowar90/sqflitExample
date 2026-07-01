import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers.dart';
import '../theme.dart';
import '../models.dart';

class SalesHistoryScreen extends ConsumerWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(salesProvider);

    // Calculate metrics
    final double totalRevenue = transactions.fold(
      0,
      (sum, t) => sum + t.totalPrice,
    );
    final int totalQuantity = transactions.fold(
      0,
      (sum, t) => sum + t.quantity,
    );
    final int transactionCount = transactions.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sales Log',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: AppTheme.secondaryColor,
                    ),
                    onPressed: () =>
                        ref.read(salesProvider.notifier).loadTransactions(),
                    tooltip: 'Refresh Log',
                  ),
                ],
              ),
            ),

            // Metrics Row Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.cardGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricItem(
                      label: 'Revenue',
                      value: '\$${totalRevenue.toStringAsFixed(2)}',
                      icon: Icons.monetization_on_outlined,
                      color: AppTheme.secondaryColor,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    _buildMetricItem(
                      label: 'Sold Qty',
                      value: '$totalQuantity',
                      icon: Icons.shopping_bag_outlined,
                      color: Colors.cyan,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    _buildMetricItem(
                      label: 'Sales Count',
                      value: '$transactionCount',
                      icon: Icons.receipt_long_outlined,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
            ),

            // Transactions Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 5),
              child: Text(
                'Transaction History',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // List View
            Expanded(
              child: transactions.isEmpty
                  ? _buildEmptyState(context, ref)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        return _buildTransactionCard(tx);
                      },
                    ),
            ),
          ],
        ),
      ),
      // Developer reset database floating button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _confirmReset(context, ref),
        label: const Text('Reset DB', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.restart_alt, color: Colors.white),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(SaleTransaction tx) {
    // Format timestamp nicely
    final year = tx.timestamp.year;
    final month = tx.timestamp.month.toString().padLeft(2, '0');
    final day = tx.timestamp.day.toString().padLeft(2, '0');
    final hour = tx.timestamp.hour.toString().padLeft(2, '0');
    final min = tx.timestamp.minute.toString().padLeft(2, '0');
    final dateStr = '$year-$month-$day';
    final timeStr = '$hour:$min';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Receipt Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.productName,
                  style: GoogleFonts.outfit(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.access_time,
                      size: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Quantity & Total Price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+\$${tx.totalPrice.toStringAsFixed(2)}',
                style: GoogleFonts.outfit(
                  color: AppTheme.secondaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${tx.quantity} units',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No sales logged yet',
              style: GoogleFonts.outfit(
                color: AppTheme.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Go to the Sales screen to complete your first transaction.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Reset Database',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'WARNING: This will delete ALL products and sales history. This action cannot be undone. Are you sure?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final dbHelper = ref.read(dbHelperProvider);
                await dbHelper.clearDatabase();

                // Refresh states
                await ref.read(productListProvider.notifier).loadProducts();
                await ref.read(salesProvider.notifier).loadTransactions();

                if (context.mounted) Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Database reset successfully'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: const Text('Reset All'),
            ),
          ],
        );
      },
    );
  }
}
