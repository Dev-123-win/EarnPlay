import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WithdrawalHistoryScreen extends StatelessWidget {
  const WithdrawalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = ModalRoute.of(context)?.settings.arguments as String?;

    return Scaffold(
      appBar: AppBar(title: const Text('Withdrawal History')),
      body: uid == null
          ? const Center(child: Text('No user id provided'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('withdrawals')
                  .where('userId', isEqualTo: uid)
                  .orderBy('requestedAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No withdrawals yet'));
                }

                final docs = snapshot.data!.docs;
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final status = (data['status'] ?? 'PENDING').toString();
                    final amount = data['amount'] ?? 0;
                    final requestedAt = data['requestedAt'];

                    final dateStr = requestedAt != null
                        ? (requestedAt is Timestamp
                              ? requestedAt.toDate().toLocal().toString()
                              : requestedAt.toString())
                        : '';

                    return ListTile(
                      title: Text('$amount coins'),
                      subtitle: Text(
                        'Status: $status${dateStr.isNotEmpty ? ' · $dateStr' : ''}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Copy transaction id',
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          final id = docs[index].id;
                          Clipboard.setData(ClipboardData(text: id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Transaction id copied'),
                            ),
                          );
                        },
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Withdrawal Details'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Amount: $amount'),
                                Text('Status: $status'),
                                const SizedBox(height: 8),
                                Text('Id: ${docs[index].id}'),
                                if (requestedAt != null) ...[
                                  const SizedBox(height: 6),
                                  Text('Requested: $dateStr'),
                                ],
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                              TextButton(
                                onPressed: () {
                                  final id = docs[index].id;
                                  Clipboard.setData(ClipboardData(text: id));
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Transaction id copied'),
                                    ),
                                  );
                                },
                                child: const Text('Copy Id'),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
