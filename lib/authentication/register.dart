import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as fStorage;
import 'package:riders_app/global/global.dart';
import 'package:riders_app/screens/home_screen.dart';
import 'package:riders_app/widgets/custom_text_field.dart';
import 'package:riders_app/widgets/error_dialog.dart';
import 'package:riders_app/widgets/loadin_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController locationController = TextEditingController();

  XFile? imageXFile;
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Position? position;
  List<Placemark>? placeMarks;

  String sellerImageUrl = "";
  String completeAddress = "";

//this function allows the user to pic image from gallery
  Future<void> _getImage() async {
    imageXFile = await _picker.pickImage(source: ImageSource.gallery);
    setState(() {
      imageXFile;
    });
  }

  getCurrentLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    Position newPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low);
    position = newPosition;
    //now we want to get the lattitude and longitude for position
    placeMarks =
        await placemarkFromCoordinates(position!.latitude, position!.longitude);
    //google will provide list of location we will get the exact loaction at 0th index
    Placemark pMark = placeMarks![0];
    //now we have to get the address the textual address
    completeAddress =
        '${pMark.subThoroughfare} ${pMark.thoroughfare},${pMark.subLocality} ${pMark.locality} ,${pMark.subAdministrativeArea}, ${pMark.administrativeArea} ${pMark.postalCode} ${pMark.country}';
    // now we have complete address and now we will assign to our location controller
    locationController.text = completeAddress;
  }

  Future<void> formValidation() async {
    if (imageXFile == null) {
      showDialog(
          context: context,
          builder: (c) => ErrorDialog(
                message: "Please Select an Image",
              ));
    } else {
      if (passwordController.text == confirmPasswordController.text) {
        //start uploading image
        if (emailController.text.isNotEmpty &&
            passwordController.text.isNotEmpty &&
            confirmPasswordController.text.isNotEmpty &&
            phoneController.text.isNotEmpty &&
            locationController.text.isNotEmpty) {
          showDialog(
              context: context,
              builder: (c) {
                return LoadingDialog(
                  message: "Registering Account",
                );
              });
          //for storing the sellers images to the storage for that create a separate folder by the name sellers

          String fileName = DateTime.now().millisecondsSinceEpoch.toString();
          fStorage.Reference reference = fStorage.FirebaseStorage.instance
              .ref()
              .child("riders")
              .child(fileName);
          fStorage.UploadTask uploadTask =
              reference.putFile(File(imageXFile!.path));
          //this is the link for accessing our images or any file from the firebase storage
          fStorage.TaskSnapshot taskSnapshot =
              await uploadTask.whenComplete(() {});
          await taskSnapshot.ref.getDownloadURL().then((url) {
            sellerImageUrl = url;

            //save information to firebase database
            authenticateAndSignUp();
          }); //this is the url where we put our image so using this url we can access this the specific image

        } else {
          showDialog(
              context: context,
              builder: (c) => ErrorDialog(
                    message:
                        "Please write the required info for the Registration",
                  ));
        }
      } else {
        showDialog(
            context: context,
            builder: (c) => ErrorDialog(
                  message: "Password do not match",
                ));
      }
    }
  }

  void authenticateAndSignUp() async {
    User? currentUser;

    await firebaseAuth
        .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim())
        .then((auth) {
      currentUser = auth.user;
    }).catchError((error) {
      Navigator.pop(context);
      showDialog(
          context: context,
          builder: (c) => ErrorDialog(
                message: error.message.toString(),
              ));
    });
    if (currentUser != null) {
      saveDataToFirestore(currentUser!).then((value) {
        Navigator.pop(context);
        //send user to home page
        Route newRoute = MaterialPageRoute(builder: (c) => HomeScreen());
        Navigator.pushReplacement(context, newRoute);
      });
    }
  }

  Future saveDataToFirestore(User currentUser) async {
    FirebaseFirestore.instance.collection("riders").doc(currentUser.uid).set({
      "riderUID": currentUser.uid,
      "riderEmail": currentUser.email,
      "riderName": nameController.text.trim(),
      "riderAvatarUrl": sellerImageUrl,
      "phone": phoneController.text.trim(),
      "address": completeAddress,
      "status": "approved",
      "earnings": 0.0,
      // "lat": position!.latitude,
      // "lng": position!.longitude,
    });
    //save data locally
    sharedPreferences = await SharedPreferences.getInstance(); //instance
    await sharedPreferences!.setString("uid", currentUser.uid);
    await sharedPreferences!.setString("email", currentUser.email.toString());
    await sharedPreferences!.setString("name", nameController.text.trim());
    await sharedPreferences!.setString("photoUrl", sellerImageUrl);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          const SizedBox(
            height: 10,
          ),
          InkWell(
            onTap: () {
              _getImage();
            },
            child: CircleAvatar(
              radius: MediaQuery.of(context).size.width * .2,
              backgroundColor: Colors.white,
              backgroundImage: imageXFile == null
                  ? null
                  : FileImage(
                      File(imageXFile!.path),
                    ),
              child: imageXFile == null
                  ? Icon(
                      Icons.add_photo_alternate,
                      size: MediaQuery.of(context).size.width * .2,
                      color: Colors.grey,
                    )
                  : null,
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          Form(
            key: _formKey,
            child: Column(
              children: [
                CustomTextField(
                  controller: nameController,
                  data: Icons.person,
                  hintText: "Name",
                  isObscure: false,
                ),
                CustomTextField(
                  controller: emailController,
                  data: Icons.email,
                  hintText: "Email",
                  isObscure: false,
                ),
                CustomTextField(
                  controller: passwordController,
                  data: Icons.lock,
                  hintText: "Password",
                  isObscure: true,
                ),
                CustomTextField(
                  controller: confirmPasswordController,
                  data: Icons.person,
                  hintText: "ConfirmPassword",
                  isObscure: true,
                ),
                CustomTextField(
                  controller: phoneController,
                  data: Icons.phone,
                  hintText: "Phone number",
                  isObscure: false,
                ),
                CustomTextField(
                  controller: locationController,
                  data: Icons.my_location,
                  hintText: "My Current address",
                  isObscure: false,
                  enabled: true,
                ),
                Container(
                  width: 400,
                  height: 40,
                  alignment: Alignment.center,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      getCurrentLocation();
                    },
                    icon: const Icon(
                      Icons.location_on,
                      color: Colors.white,
                    ),
                    label: const Text(
                      "Get my Current Location",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                        primary: Colors.amber,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        )),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          ElevatedButton(
            onPressed: () => formValidation(),
            child: const Text(
              "Register",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
            style: ElevatedButton.styleFrom(
                primary: Colors.purple,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 50)),
          ),
          const SizedBox(
            height: 20,
          ),
        ],
      ),
    );
  }
}
