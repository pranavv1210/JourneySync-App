import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  final supabase = Supabase.instance.client;

  String userName = "Rider";
  String bikeName = "No bike";

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future loadUserData() async {

    final user = supabase.auth.currentUser;

    if(user == null) return;

    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    setState(() {

      userName = data['name'] ?? "Rider";

      bikeName = data['bike'] ?? "Add Bike";

    });

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF8F7F6),

      body: SafeArea(

        child: Padding(

          padding: const EdgeInsets.all(20),

          child: Column(

            children: [

              /// HEADER

              Row(

                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      const Text(
                        "WELCOME BACK",
                        style: TextStyle(
                          color: Color(0xFFD46211),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text(
                        "Let's ride, $userName",
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A2F),
                        ),
                      ),

                    ],
                  ),

                  const CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.orange,
                  )

                ],
              ),

              const SizedBox(height: 30),

              /// BIKE CARD

              Container(

                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(

                  color: Colors.white,

                  borderRadius: BorderRadius.circular(20),

                ),

                child: Row(

                  children: [

                    const Icon(Icons.motorcycle),

                    const SizedBox(width: 10),

                    Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        const Text("My Bike"),

                        Text(
                          bikeName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                      ],
                    )

                  ],
                ),

              ),

              const SizedBox(height: 30),

              /// CREATE RIDE BUTTON

              GestureDetector(

                onTap: () {

                  print("Create Ride Clicked");

                },

                child: Container(

                  height: 160,

                  decoration: BoxDecoration(

                    color: const Color(0xFFD46211),

                    borderRadius: BorderRadius.circular(30),

                  ),

                  child: const Center(

                    child: Text(
                      "Create Ride",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                  ),

                ),

              ),

            ],
          ),

        ),

      ),

    );

  }

}
