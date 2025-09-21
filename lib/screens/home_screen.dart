// lib/screens/home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'search_results_screen.dart';
import 'add_product_screen.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final double? price;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    this.price,
  });

  factory Product.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      price: (data['price'] is num) ? (data['price'] as num).toDouble() : null,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCategory = 'All';
  final TextEditingController _searchCtrl = TextEditingController();

  Stream<QuerySnapshot> _productsStream() {
    final col = FirebaseFirestore.instance
        .collection('products')
        .orderBy('createdAt', descending: true);
    // Simple category filter placeholder: if you store category in doc, adjust here
    return col.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final chips = ['All', 'Lamps', 'Textiles', 'Pottery', 'Paintings'];
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search crafts or artisans',
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onSubmitted: (q) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            SearchResultsScreen(query: q, searchResults: null),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddProductScreen()),
                ),
                icon: const Icon(
                  Icons.add_circle,
                  size: 34,
                  color: Colors.deepPurple,
                ),
                tooltip: 'Add product',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Category chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final label = chips[i];
                final sel = label == selectedCategory;
                return ChoiceChip(
                  label: Text(label),
                  selected: sel,
                  onSelected: (_) => setState(() => selectedCategory = label),
                  selectedColor: Colors.deepPurple.shade100,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Featured Crafts',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _productsStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox, size: 72, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        const Text('No products yet. Add one!'),
                      ],
                    ),
                  );
                }
                final docs = snap.data!.docs;
                final products = docs.map((d) => Product.fromDoc(d)).toList();
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (ctx, idx) =>
                      ProductCard(product: products[idx]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetail(product: product)),
      ),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: product.id,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: Image.network(
                  product.imageUrl,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product.price != null
                            ? '₹${product.price!.toStringAsFixed(0)}'
                            : '—',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () {
                          /* TODO: wishlist */
                        },
                        icon: const Icon(Icons.favorite_border),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductDetail extends StatelessWidget {
  final Product product;
  const ProductDetail({super.key, required this.product});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Hero(
              tag: product.id,
              child: Image.network(
                product.imageUrl,
                height: 280,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.price != null
                        ? '₹${product.price!.toStringAsFixed(0)}'
                        : 'Price on request',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(product.description),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      /* contact owner */
                    },
                    icon: const Icon(Icons.chat),
                    label: const Text('Contact Seller'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
