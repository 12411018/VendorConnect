import 'package:flutter/material.dart';
import 'wholesaler_dashboard.dart';
import 'retailer_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  String role = "wholesaler";

  // Form key to control form validation
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: const Text("VendorConnect Login"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Form(
          key: _formKey,

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              const Text(
                "Select Role",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  ChoiceChip(
                    label: const Text("Wholesaler"),
                    selected: role == "wholesaler",
                    selectedColor: const Color(0xFF6366F1),
                    onSelected: (value) {
                      setState(() {
                        role = "wholesaler";
                      });
                    },
                  ),

                  const SizedBox(width: 20),

                  ChoiceChip(
                    label: const Text("Retailer"),
                    selected: role == "retailer",
                    selectedColor: const Color(0xFF6366F1),
                    onSelected: (value) {
                      setState(() {
                        role = "retailer";
                      });
                    },
                  ),

                ],
              ),

              const SizedBox(height: 40),

              TextFormField(
                decoration: InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter email";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              TextFormField(
                obscureText: true,

                decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter password";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),

                onPressed: () {

                  if (_formKey.currentState!.validate()) {

                    if(role == "wholesaler"){

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WholesalerDashboard(),
                        ),
                      );

                    } else {

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RetailerDashboard(),
                        ),
                      );
                    }
                  }

                },

                child: const Text("Login"),
              )

            ],
          ),
        ),
      ),
    );
  }
}