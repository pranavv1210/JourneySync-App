import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateRideScreen extends StatefulWidget {
  const CreateRideScreen({super.key});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {

  final TextEditingController rideNameController = TextEditingController();

  final supabase = Supabase.instance.client;

  Future<void> createRide() async {

    final rideName = rideNameController.text;

    if (rideName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter ride name")),
      );
      return;
    }

    await supabase.from('rides').insert({
      'name': rideName,
      'leader_id': 'demo-user',
      'status': 'waiting',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Ride Created Successfully")),
    );

    rideNameController.clear();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Create Ride"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(

          children: [

            TextField(
              controller: rideNameController,
              decoration: const InputDecoration(
                labelText: "Ride Name",
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: createRide,
              child: const Text("Create Ride"),
            ),

          ],
        ),
      ),
    );
  }
}
