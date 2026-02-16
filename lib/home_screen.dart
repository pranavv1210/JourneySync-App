import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  String userName = "";
  String userBike = "";

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future loadUser() async {

    final prefs = await SharedPreferences.getInstance();

    setState(() {

      userName = prefs.getString("userName") ?? "Rider";

      userBike = prefs.getString("userBike") ?? "Add Bike";

    });

  }

  @override
  Widget build(BuildContext context) {

    const primary = Color(0xFFD46211);
    const forest = Color(0xFF1E3A2F);
    const background = Color(0xFFF8F7F6);

    return Scaffold(

      backgroundColor: background,

      body: SafeArea(

        child: SingleChildScrollView(

          padding: const EdgeInsets.all(20),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              /// HEADER

              Row(

                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [

                  Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(
                        "WELCOME BACK",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),

                      Text(
                        "Let's ride, $userName",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: forest,
                        ),
                      ),

                    ],
                  ),

                  const CircleAvatar(
                    radius: 25,
                    backgroundImage: AssetImage("assets/logo.png"),
                  ),

                ],
              ),

              const SizedBox(height: 30),

              /// WEATHER + BIKE

              Row(

                children: [

                  Expanded(

                    child: containerCard(

                      icon: Icons.wb_sunny,
                      title: "Weather",
                      value: "27°C Clear",

                    ),

                  ),

                  const SizedBox(width: 15),

                  Expanded(

                    child: containerCard(

                      icon: Icons.motorcycle,
                      title: "My Bike",
                      value: userBike,

                    ),

                  ),

                ],
              ),

              const SizedBox(height: 30),

              /// CREATE RIDE

              GestureDetector(

                onTap: () {

                  print("Create Ride");

                },

                child: Container(

                  height: 170,

                  width: double.infinity,

                  decoration: BoxDecoration(

                    color: primary,

                    borderRadius: BorderRadius.circular(25),

                  ),

                  child: Padding(

                    padding: const EdgeInsets.all(20),

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      mainAxisAlignment: MainAxisAlignment.end,

                      children: [

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: const Icon(Icons.add,color: Colors.white),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          "Create Ride",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        Text(
                          "Plan a route and invite friends",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                          ),
                        ),

                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              /// NEARBY RIDES

              Container(

                padding: const EdgeInsets.all(20),

                decoration: BoxDecoration(

                  border: Border.all(color: primary,width: 2),

                  borderRadius: BorderRadius.circular(20),

                  color: Colors.white,

                ),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Row(

                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [

                        const Icon(Icons.near_me,color: primary),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal:10,vertical:5),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text("LIVE"),
                        )

                      ],
                    ),

                    const SizedBox(height: 10),

                    Text(
                      "Nearby Active Rides",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: forest,
                      ),
                    ),

                    const Text("3 groups riding near you"),

                  ],
                ),
              ),

              const SizedBox(height: 30),

              /// RECENT

              Row(

                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [

                  Text(
                    "Recent Journeys",
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),

                  Text(
                    "View All",
                    style: GoogleFonts.plusJakartaSans(
                      color: primary,
                    ),
                  ),

                ],
              ),

              const SizedBox(height: 15),

              journeyCard("Sunday Canyon Run","45 km","1h 20m"),

              const SizedBox(height: 10),

              journeyCard("Mountain Ride","80 km","2h 30m"),

            ],
          ),
        ),
      ),

      /// BOTTOM NAV

      bottomNavigationBar: BottomNavigationBar(

        selectedItemColor: primary,

        items: const [

          BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Home"),

          BottomNavigationBarItem(
              icon: Icon(Icons.map),
              label: "Map"),

          BottomNavigationBarItem(
              icon: Icon(Icons.garage),
              label: "Garage"),

          BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: "Settings"),

        ],
      ),

    );
  }

  Widget containerCard({
    required IconData icon,
    required String title,
    required String value,
  }) {

    return Container(

      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(15),

      ),

      child: Row(

        children: [

          Icon(icon),

          const SizedBox(width:10),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          )

        ],
      ),
    );
  }

  Widget journeyCard(String title,String distance,String time){

    return Container(

      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(15),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold)),

          Text("$distance • $time"),

        ],
      ),
    );
  }

}
