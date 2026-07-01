import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers.dart';
import '../theme.dart';
import '../models.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, required this.quantity});

  double get totalPrice => product.price * quantity;
}

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen>
    with SingleTickerProviderStateMixin {
  final List<CartItem> _cart = [];
  bool _canScan = true;
  final MobileScannerController _scannerController = MobileScannerController();
  late AnimationController _scannerAnimationController;
  late Animation<double> _scannerLineAnimation;

  @override
  void initState() {
    super.initState();
    // Setting up the laser line animation for the scanner
    _scannerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scannerLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scannerAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _scannerAnimationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _scannerAnimationController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _processBarcode(String barcode) async {
    final products = ref.read(productListProvider);
    final matchedProduct = products.firstWhere(
      (p) => p.barcode == barcode,
      orElse: () =>
          Product(id: -1, name: '', price: 0, quantity: 0, barcode: ''),
    );

    if (matchedProduct.id == -1) {
      // Prompt user to add the new product inline!
      _showAddProductDialog(barcode);
      return;
    }

    if (matchedProduct.quantity <= 0) {
      _showScanFeedbackSnackBar(
        '"${matchedProduct.name}" is out of stock!',
        isError: true,
      );
      _resetScanWithDelay();
      return;
    }

    // Add to cart logic
    setState(() {
      final existingIndex = _cart.indexWhere(
        (item) => item.product.id == matchedProduct.id,
      );
      if (existingIndex >= 0) {
        final currentQtyInCart = _cart[existingIndex].quantity;
        if (currentQtyInCart < matchedProduct.quantity) {
          _cart[existingIndex].quantity++;
          _showScanFeedbackSnackBar(
            'Incremented quantity of "${matchedProduct.name}"',
          );
        } else {
          _showScanFeedbackSnackBar(
            'Cannot add more. Limit reached for "${matchedProduct.name}"',
            isError: true,
          );
        }
      } else {
        _cart.add(CartItem(product: matchedProduct, quantity: 1));
        _showScanFeedbackSnackBar('Added "${matchedProduct.name}" to bill');
      }
    });

    _resetScanWithDelay();
  }

  void _resetScanWithDelay() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _canScan = true;
          _scannerAnimationController.repeat(reverse: true);
        });
      }
    });
  }

  void _showAddProductDialog(String barcode) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final quantityController = TextEditingController(
      text: '10',
    ); // Default stock

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'New Product QR Detected',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'QR Code "$barcode" is not registered. Quick add it to database to sell.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name',
                      hintText: 'e.g. Wireless Charger',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Product name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: priceController,
                          decoration: const InputDecoration(
                            labelText: 'Price (\$)',
                            hintText: '0.00',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Required';
                            }
                            if (double.tryParse(val) == null) {
                              return 'Invalid';
                            }
                            if (double.parse(val) <= 0) {
                              return '> 0';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: quantityController,
                          decoration: const InputDecoration(
                            labelText: 'Stock Qty',
                            hintText: '10',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Required';
                            }
                            if (int.tryParse(val) == null) {
                              return 'Invalid';
                            }
                            if (int.parse(val) < 0) {
                              return '>= 0';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: barcode,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'QR Barcode (Pre-filled)',
                      fillColor: Colors.black12,
                    ),
                  ),
                ],
              ),
            ),
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
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  final price = double.parse(priceController.text.trim());
                  final quantity = int.parse(quantityController.text.trim());

                  final success = await ref
                      .read(productListProvider.notifier)
                      .addProduct(name, price, quantity, barcode);

                  if (success) {
                    if (context.mounted) Navigator.pop(context);

                    // Reload products list state & find the newly added product
                    final listNotifier = ref.read(productListProvider.notifier);
                    await listNotifier.loadProducts();
                    final updatedProducts = ref.read(productListProvider);

                    final newProduct = updatedProducts.firstWhere(
                      (p) => p.barcode == barcode,
                      orElse: () => Product(
                        id: -1,
                        name: '',
                        price: 0,
                        quantity: 0,
                        barcode: '',
                      ),
                    );

                    if (newProduct.id != -1 && quantity > 0) {
                      setState(() {
                        _cart.add(CartItem(product: newProduct, quantity: 1));
                      });
                      _showScanFeedbackSnackBar(
                        'Product added to DB and active bill.',
                      );
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Error adding product to database.'),
                          backgroundColor: AppTheme.errorColor,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Add & Add to Cart'),
            ),
          ],
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _canScan = true;
          _scannerAnimationController.repeat(reverse: true);
        });
      }
    });
  }

  void _showScanFeedbackSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? AppTheme.errorColor
            : AppTheme.secondaryColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _checkout() async {
    if (_cart.isEmpty) return;

    setState(() {
      _canScan = false;
      _scannerAnimationController.stop();
    });

    // Show loading spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.secondaryColor),
      ),
    );

    bool allSuccess = true;
    final salesNotifier = ref.read(salesProvider.notifier);

    for (final item in _cart) {
      if (item.product.id != null) {
        final success = await salesNotifier.checkoutProduct(
          item.product.id!,
          item.quantity,
          item.totalPrice,
        );
        if (!success) {
          allSuccess = false;
        }
      }
    }

    if (!mounted) return;
    Navigator.pop(context); // Pop loading spinner

    if (allSuccess) {
      // Build summary invoice details before clearing cart
      final invoiceItems = List<CartItem>.from(_cart);
      final double totalBill = invoiceItems.fold(
        0,
        (sum, item) => sum + item.totalPrice,
      );

      setState(() {
        _cart.clear();
      });

      _showReceiptDialog(invoiceItems, totalBill);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Checkout failed for one or more items due to stock constraints.',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      setState(() {
        _canScan = true;
        _scannerAnimationController.repeat(reverse: true);
      });
    }
  }

  void _showReceiptDialog(List<CartItem> items, double total) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: Column(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: AppTheme.secondaryColor,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                'Sale Completed!',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store Info
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'SMART RETAIL POS',
                          style: GoogleFonts.shareTechMono(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Offline Local Store',
                          style: GoogleFonts.shareTechMono(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '----------------------------',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Transaction Time
                  Text(
                    'DATE: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
                    style: GoogleFonts.shareTechMono(
                      color: Colors.black,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'TIME: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.shareTechMono(
                      color: Colors.black,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '----------------------------',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontFamily: 'monospace',
                    ),
                  ),

                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ITEM',
                        style: GoogleFonts.shareTechMono(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'TOTAL',
                        style: GoogleFonts.shareTechMono(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '----------------------------',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontFamily: 'monospace',
                    ),
                  ),

                  // Items list
                  ...items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.name,
                                  style: GoogleFonts.shareTechMono(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${item.quantity} x \$${item.product.price.toStringAsFixed(2)}',
                                  style: GoogleFonts.shareTechMono(
                                    color: Colors.black87,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '\$${item.totalPrice.toStringAsFixed(2)}',
                            style: GoogleFonts.shareTechMono(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  Text(
                    '----------------------------',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontFamily: 'monospace',
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'GRAND TOTAL:',
                        style: GoogleFonts.shareTechMono(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '\$${total.toStringAsFixed(2)}',
                        style: GoogleFonts.shareTechMono(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '----------------------------',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'THANK YOU FOR SHOPPING!',
                      style: GoogleFonts.shareTechMono(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                // Show a quick simulated print job status snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Receipt sent to POS Printer!'),
                    backgroundColor: AppTheme.secondaryColor,
                  ),
                );
              },
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print Receipt'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppTheme.primaryColor.withValues(alpha: 0.5),
                ),
                foregroundColor: AppTheme.textPrimaryColor,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: Colors.black,
              ),
              child: const Text('New Sale'),
            ),
          ],
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _canScan = true;
          _scannerAnimationController.repeat(reverse: true);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double subtotal = _cart.fold(0, (sum, item) => sum + item.totalPrice);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Screen Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QR Code Sales POS',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Simulate scanning QR codes on products to complete sales',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),

            // Scanning Viewfinder Screen
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _canScan
                        ? AppTheme.secondaryColor
                        : Colors.white.withValues(alpha: 0.1),
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    // Live camera scan view
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: MobileScanner(
                          controller: _scannerController,
                          onDetect: (capture) {
                            if (!_canScan) return;
                            final barcodes = capture.barcodes;
                            if (barcodes.isEmpty) return;
                            final barcode = barcodes.first.rawValue;
                            if (barcode == null || barcode.isEmpty) return;

                            setState(() {
                              _canScan = false;
                              _scannerAnimationController.stop();
                            });
                            _processBarcode(barcode);
                          },
                        ),
                      ),
                    ),

                    // Corner borders overlay
                    _buildScannerCorners(),
                    // Grid background
                    _buildScannerGrid(),

                    // Sliding laser line animation
                    if (_canScan)
                      AnimatedBuilder(
                        animation: _scannerLineAnimation,
                        builder: (context, child) {
                          return Positioned(
                            top: _scannerLineAnimation.value * 160 + 10,
                            left: 10,
                            right: 10,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryColor,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.secondaryColor.withValues(
                                      alpha: 0.8,
                                    ),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    // Viewfinder overlay instructions
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _canScan
                                ? Icons.center_focus_strong
                                : Icons.center_focus_weak,
                            size: 48,
                            color: _canScan
                                ? AppTheme.secondaryColor
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _canScan
                                ? 'SCANNING FOR QR CODE...'
                                : 'SCANNER PAUSED...',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: _canScan
                                  ? AppTheme.secondaryColor
                                  : Colors.white.withValues(alpha: 0.5),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Active Bill Cart Listing
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Checkout Bill',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            color: AppTheme.textPrimaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Items: ${_cart.fold<int>(0, (sum, i) => sum + i.quantity)}',
                          style: const TextStyle(
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _cart.isEmpty
                        ? _buildEmptyCartPlaceholder()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _cart.length,
                            itemBuilder: (context, index) {
                              final item = _cart[index];
                              return _buildCartItemCard(item, index);
                            },
                          ),
                  ),
                ],
              ),
            ),

            // Checkout Bottom Bar
            if (_cart.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Bill Amount',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        Text(
                          '\$${subtotal.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            color: AppTheme.secondaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _checkout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondaryColor,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.print_rounded),
                            const SizedBox(width: 10),
                            Text(
                              'Confirm Sale & Print',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItemCard(CartItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          // Index Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: GoogleFonts.outfit(
                    color: AppTheme.textPrimaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Price: \$${item.product.price.toStringAsFixed(2)} | Sub: \$${item.totalPrice.toStringAsFixed(2)}',
                  style: GoogleFonts.outfit(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Quantity controls
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: AppTheme.textSecondaryColor,
                  size: 22,
                ),
                onPressed: () {
                  setState(() {
                    if (item.quantity > 1) {
                      item.quantity--;
                    } else {
                      _cart.removeAt(index);
                    }
                  });
                },
              ),
              Text(
                '${item.quantity}',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: AppTheme.secondaryColor,
                  size: 22,
                ),
                onPressed: () {
                  // Validate stock level
                  if (item.quantity < item.product.quantity) {
                    setState(() {
                      item.quantity++;
                    });
                  } else {
                    _showScanFeedbackSnackBar(
                      'Insufficient stock of "${item.product.name}"',
                      isError: true,
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCartPlaceholder() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_shopping_cart,
              size: 36,
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'Bill is empty.',
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan a product\'s QR code using the camera to add it to the cart.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerCorners() {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: CustomPaint(
          painter: ScannerBorderPainter(
            color: _canScan
                ? AppTheme.secondaryColor
                : Colors.white.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerGrid() {
    return Positioned.fill(
      child: Opacity(
        opacity: _canScan ? 0.05 : 0.02,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 10,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
          ),
          itemCount: 80,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 0.5),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ScannerBorderPainter extends CustomPainter {
  final Color color;

  ScannerBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const cornerLength = 20.0;

    // Top-Left corner
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // Top-Right corner
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerLength),
      paint,
    );

    // Bottom-Left corner
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerLength, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - cornerLength),
      paint,
    );

    // Bottom-Right corner
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - cornerLength, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
