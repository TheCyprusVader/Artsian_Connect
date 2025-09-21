import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  File? _imageFile;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();

  String _generatedDescription = '';
  bool _isLoading = false;

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _generatedDescription = '';
      });
    }
  }

  Future<void> _generateAndSaveContent() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first.')),
      );
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a product name.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Step 1: Upload image to Firebase Storage
      final fileName = 'products/${_uuid.v4()}.jpg';
      final ref = _storage.ref().child(fileName);
      final snapshot = await ref.putFile(_imageFile!).whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Step 2: Ensure user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to add products.'),
          ),
        );
        return;
      }

      // Step 3: Call Cloud Function for AI enrichment
      final result = await FirebaseFunctions.instance
          .httpsCallable('generateContent')
          .call({
            'imageUrl': downloadUrl,
            'name': _nameController.text.trim(),
            'price': double.tryParse(_priceController.text.trim()),
            'prompt': _promptController.text.trim(),
            'userEmail': user.email ?? '',
            'uid': user.uid,
          });

      setState(() {
        _generatedDescription = result.data['generated'] ?? '';
      });

      // Step 4: Save product in Firestore
      await FirebaseFunctions.instance.httpsCallable('saveData').call({
        'collection': 'products',
        'payload': {
          'name': _nameController.text.trim(),
          'price': double.tryParse(_priceController.text.trim()),
          'description': _generatedDescription,
          'imageUrl': downloadUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'ownerId': user.uid,
          'ownerEmail': user.email ?? '',
        },
      });

      // Step 5: Success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product successfully listed with AI!')),
      );

      // Clear inputs
      setState(() {
        _imageFile = null;
        _nameController.clear();
        _priceController.clear();
        _promptController.clear();
      });
    } catch (e) {
      print('Error saving product: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'AI-Assisted Product Listing',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Image picker
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepPurple, width: 2),
                color: Colors.deepPurple.withOpacity(0.1),
              ),
              child: _imageFile == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo,
                          size: 50,
                          color: Colors.deepPurple,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap to select an image',
                          style: TextStyle(color: Colors.deepPurple),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_imageFile!, fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Product name
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Product Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.shopping_bag),
            ),
          ),
          const SizedBox(height: 16),

          // Price field
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Price (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.currency_rupee),
            ),
          ),
          const SizedBox(height: 16),

          // Prompt/description input
          TextField(
            controller: _promptController,
            decoration: const InputDecoration(
              labelText: 'Enter a short description (optional)',
              hintText: 'e.g., "Hand-painted brass lamp"',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.edit),
            ),
          ),
          const SizedBox(height: 16),

          // Upload button
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _generateAndSaveContent,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome, color: Colors.white),
            label: Text(_isLoading ? 'Saving...' : 'Generate & Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Generated description preview
          if (_generatedDescription.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Product Description:',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _generatedDescription,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
