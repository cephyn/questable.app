# Plan: Backend PDF-to-Markdown Conversion using Firebase Cloud Functions

This plan outlines the steps to create a Firebase Cloud Function that uses the `opengovsg/pdf2md` library to convert uploaded PDF files to Markdown. The Flutter application will then interact with this function.

**Overall Status:** In Progress

## 1. Firebase Cloud Function Setup (Node.js)

### 1.1. Set Up a New Node.js Firebase Functions Codebase
**Status: COMPLETED**
   - Firebase supports multiple functions codebases. We will set up a new codebase for our Node.js functions, separate from the existing Python functions (which are typically in a `functions/` directory).
   - **Create a new directory for the Node.js functions:** **(COMPLETED)**
     For example, `functions_node` at the root of your Firebase project.
     ```powershell
     mkdir functions_node
     cd functions_node
     ```
   - **Initialize a Node.js project inside this new directory:** **(COMPLETED)**
     ```powershell
     npm init -y
     ```
     _(Verified `package.json` exists in `functions_node`)_
   - **Install core Firebase dependencies for this codebase:** **(COMPLETED)**
     Make sure you are in the `functions_node` directory.
     ```powershell
     npm install firebase-functions firebase-admin
     ```
     _(Verified `firebase-functions` and `firebase-admin` are in `functions_node/package.json` dependencies)_
     Then navigate back to your project root:
     ```powershell
     cd ..
     ```
   - **Configure `firebase.json` for multiple codebases:** **(COMPLETED)**
     You need to inform Firebase about your new functions codebase. Modify your `firebase.json` at the project root. If you have existing Python functions (e.g., in a directory named `functions`), your `firebase.json` might look something like this after adding the Node.js codebase:
     ```json
     {
       "functions": [
         {
           "source": "functions", // Your existing Python functions directory
           "codebase": "default", // Or your chosen name for the Python codebase
           "runtime": "python311" // Or your Python runtime
         },
         {
           "source": "functions_node", // Our new Node.js functions directory
           "codebase": "node-functions", // Assign a unique name
           "runtime": "nodejs22", // Or your preferred Node.js runtime (e.g., nodejs18, nodejs20)
           "predeploy": ["npm --prefix \\"%RESOURCE_DIR%\\" run lint", "npm --prefix \\"%RESOURCE_DIR%\\" run build"] // Optional: if you have lint/build scripts in functions_node/package.json
         }
       ],
       // ... other firebase configurations (hosting, firestore, etc.)
     }
     ```
     - Adjust `codebase` names (e.g., `default`, `node-functions`) and `source` directories as per your project structure. _(Verified `firebase.json` has `functions_node` source and `node-functions` codebase)_
     - The `runtime` for Node.js functions should be a supported version. (Current: `nodejs22` - COMPLETED)
     - The `predeploy` hooks are optional and assume you have corresponding scripts (like `lint` or `build`) in your `functions_node/package.json`. (Currently not included in `firebase.json` for `functions_node` - ACCEPTABLE)

### 1.2. Create a New HTTP-Triggered Cloud Function
**Status: PENDING**
   - Navigate to your new Node.js functions directory (e.g., `functions_node`).
   - Create or open the main file for your functions, typically `index.js` (i.e., `functions_node/index.js`). **(COMPLETED - file exists but is empty)**
   - Define your new HTTP-triggered function in this file. **(PENDING - `index.js` is empty)**

### 1.3. Add Specific Dependencies for PDF Conversion
**Status: COMPLETED**
   - In your Node.js functions directory (e.g., `functions_node`), install `@opendocsg/pdf2md` for PDF conversion and `busboy` for handling multipart/form-data.
     ```powershell
     cd functions_node
     npm install @opendocsg/pdf2md busboy
     cd ..
     ```
     _(Verified `@opendocsg/pdf2md` and `busboy` are in `functions_node/package.json` dependencies)_
   - Ensure your `functions_node/package.json` reflects these dependencies, along with `firebase-functions` and `firebase-admin` (installed in step 1.1). **(COMPLETED)**
   - Your `functions_node/package.json` `dependencies` section should look something like:
     ```json
     "dependencies": {
       "firebase-admin": "^13.4.0", 
       "firebase-functions": "^6.3.2", 
       "@opendocsg/pdf2md": "^0.2.1", 
       "busboy": "^1.6.0" 
     }
     ```
     _(Versions in actual `package.json` are: `firebase-admin: ^13.4.0`, `firebase-functions: ^6.3.2`, `@opendocsg/pdf2md: ^0.2.1`, `busboy: ^1.6.0` - COMPLETED)_
   - You should also have a `main` entry in `functions_node/package.json`, e.g., `"main": "index.js"`, and an `engines` field specifying your Node.js version, e.g., `"engines": { "node": "18" }`. Add scripts like `lint` or `build` if you plan to use them in `predeploy` hooks.
     _(Verified `main: index.js` exists. `engines` field is not present - RECOMMENDED to add, but not critical for now. `type: commonjs` is present.)_

### 1.4. Implement the Cloud Function Logic
**Status: COMPLETED**
   - The function will:
     a. Receive a PDF file via an HTTP POST request (multipart/form-data).
     b. Use `busboy` to parse the incoming file.
     c. Read the PDF file into a buffer.
     d. Use `@opendocsg/pdf2md` to convert the PDF buffer to a Markdown string.
     e. **Return the Markdown:** Upload the generated Markdown text as a `.md` file to a specific path in Firebase Storage. The function will return the GCS URI (e.g., `gs://your-bucket/markdown_uploads/generated_file.md`) of this file. This approach (Option A) is chosen for its suitability for larger files and consistency in handling file-based data.
     f. Handle errors gracefully and return appropriate HTTP status codes.

   **Example Structure (in `functions_node/index.js`):**
   ```javascript
   const functions = require("firebase-functions");
   const admin = require("firebase-admin");
   const pdf2md = require("@opendocsg/pdf2md");
   const Busboy = require("busboy");
   const os = require("os");
   const path = require("path");
   const fs = require("fs");

   admin.initializeApp();

   exports.convertToMarkdown = functions.https.onRequest(async (req, res) => {
     if (req.method !== "POST") {
       return res.status(405).send("Method Not Allowed");
     }

     const busboy = Busboy({ headers: req.headers });
     const tmpdir = os.tmpdir();
     let localPdfPath; // Renamed for clarity
     let originalPdfFilename;

     // This object will hold the promise that resolves when file processing is done
     const fileProcessingPromises = [];

     busboy.on("file", (fieldname, file, filenameInfo) => {
       // filenameInfo on Firebase/Busboy is an object: { filename: 'actual_name.pdf', encoding: '...', mimeType: '...' }
       originalPdfFilename = filenameInfo.filename;
       const mimetype = filenameInfo.mimeType;

       if (mimetype !== "application/pdf") {
         // Do not send response here yet, let busboy finish.
         // Instead, mark as error and handle in busboy.on('finish')
         file.resume(); // Consume the stream to prevent hanging
         // Consider setting a flag or rejecting a promise to indicate error
         console.warn(`Invalid file type received: ${mimetype}`);
         // To properly reject, you'd need to make the outer function aware.
         // For simplicity here, we'll rely on later checks or let it fail.
         // A more robust solution would involve rejecting a main promise.
         return;
       }

       localPdfPath = path.join(tmpdir, originalPdfFilename);
       const writeStream = fs.createWriteStream(localPdfPath);
       file.pipe(writeStream);

       const promise = new Promise((resolve, reject) => {
         file.on("end", () => {
           writeStream.end();
         });
         writeStream.on("finish", resolve);
         writeStream.on("error", (err) => {
            console.error("WriteStream error:", err);
            if (fs.existsSync(localPdfPath)) {
                fs.unlinkSync(localPdfPath); // Clean up on write error
            }
            reject(err);
         });
       });
       fileProcessingPromises.push(promise);
     });

     busboy.on("field", (fieldname, val) => {
        console.log(`Processed field ${fieldname}: ${val}.`);
     });

     busboy.on("finish", async () => {
       if (!localPdfPath || !originalPdfFilename) {
         // This can happen if no file was uploaded or if it was an invalid type not processed.
         return res.status(400).send("No PDF file processed. Ensure a single PDF is uploaded with fieldname 'pdfFile'.");
       }

       try {
         await Promise.all(fileProcessingPromises); // Wait for file to be written

         const fileBuffer = fs.readFileSync(localPdfPath);
         const markdownText = await pdf2md(new Uint8Array(fileBuffer));
         
         // Clean up temporary PDF file
         fs.unlinkSync(localPdfPath);

         // --- Option A: Upload to Firebase Storage (Recommended) ---
         const bucket = admin.storage().bucket(); // Default bucket
         // Sanitize filename for storage
         const sanitizedOriginalFilename = originalPdfFilename.replace(/[^a-zA-Z0-9._-]/g, '_');
         const destination = `markdown_uploads/${Date.now()}_${sanitizedOriginalFilename}.md`;
         const storageFile = bucket.file(destination);

         await storageFile.save(markdownText, {
           metadata: { contentType: "text/markdown" },
         });
         
         const gcsUri = `gs://${bucket.name}/${destination}`;
         
         return res.status(200).json({ 
           message: "Successfully converted and uploaded Markdown.",
           markdownGcsUri: gcsUri,
         });

       } catch (error) {
         console.error("Error during PDF to Markdown conversion or upload:", error);
         if (localPdfPath && fs.existsSync(localPdfPath)) {
           fs.unlinkSync(localPdfPath); // Clean up temp file on error
         }
         return res.status(500).send("Error converting PDF to Markdown.");
       }
     });

     // Pass the request to Busboy
     // For Firebase Cloud Functions, req.rawBody is available if the function isn't configured
     // to automatically parse common body types (which it isn't for multipart/form-data by default).
     // If using a newer version or different setup where req.rawBody is not populated,
     // you might need to ensure the request stream is correctly piped.
     if (req.rawBody) {
        busboy.end(req.rawBody);
     } else {
        req.pipe(busboy);
     }
   });
   ```

### 1.5. Deploy the Cloud Function
**Status: COMPLETED**
   - To deploy only the functions from your new Node.js codebase (e.g., named `node-functions` in `firebase.json`):
     ```powershell
     firebase deploy --only functions:node-functions 
     ```
     (Replace `node-functions` with the `codebase` name you defined in `firebase.json`).
   - Or, if you want to deploy all functions from all codebases:
     ```powershell
     firebase deploy --only functions
     ```
   - After deployment, Firebase CLI will output the HTTP URL for your function. The URL format will be something like: `https://<region>-<project-id>.cloudfunctions.net/<functionName>` or `https://<region>-<project-id>.cloudfunctions.net/<codebaseName>-<functionName>` if your Firebase project settings or function definitions cause grouping. For a function `convertToMarkdown` in codebase `node-functions`, it might be `https://<region>-<project-id>.cloudfunctions.net/convertToMarkdown` if not explicitly grouped, or it could be part of a group if you export multiple functions. Note this URL for use in your Flutter app.

### 1.6. Configure Firebase Storage Rules (if using Option A)
   - Ensure your Firebase Storage rules allow:
     - The Cloud Function's service account to write to the `markdown_uploads/` path (or your chosen path).
     - Your Flutter app (or the `FirebaseVertexaiService` identity) to read from this path.
   - Example `storage.rules`:
     ```
     rules_version = '2';
     service firebase.storage {
       match /b/{bucket}/o {
         // Allow public read for generated markdown files if needed by Vertex AI
         // Or, restrict to authenticated users / specific service accounts
         match /markdown_uploads/{allPaths=**} {
           allow read; // Adjust as per your security needs for Vertex AI
           // Allow write only by your function's service account (implicitly handled if function writes)
           // Or, if Flutter app needs to write for some reason (not in this plan)
         }
         // Other rules for your app...
       }
     }
     ```
   - Test and refine these rules.

## 2. Flutter Application Modifications

### 2.1. Add Dependencies
   - Ensure you have necessary packages in your `pubspec.yaml`:
     - `http`: For making HTTP requests to the Cloud Function.
     - `file_picker`: To allow users to select PDF files.
     - `firebase_storage` (if you need to get a download URL from a GCS URI, though `FirebaseVertexaiService` might handle GCS URIs directly).
   - Run `flutter pub get`.

### 2.2. Implement File Picking
   - Use the `file_picker` package to let the user select a PDF file.
   ```dart
   // Example in your Flutter widget/service
   import 'package:file_picker/file_picker.dart';
   import 'dart:io'; // For File type

   Future<File?> pickPdfFile() async {
     FilePickerResult? result = await FilePicker.platform.pickFiles(
       type: FileType.custom,
       allowedExtensions: ['pdf'],
     );

     if (result != null && result.files.single.path != null) {
       return File(result.files.single.path!);
     }
     return null;
   }
   ```

### 2.3. Call the Cloud Function
   - Create a service or method in Flutter to send the picked PDF to your Cloud Function.
   - Use the `http` package to make a multipart POST request.

   ```dart
   // Example in your Flutter service
   import 'package:http/http.dart' as http;
   import 'dart:convert'; // For jsonDecode

   Future<String?> uploadPdfForConversion(File pdfFile) async {
     // Replace with your Cloud Function URL
     var url = Uri.parse('YOUR_CLOUD_FUNCTION_URL_HERE');
     var request = http.MultipartRequest('POST', url);
     
     request.files.add(
       await http.MultipartFile.fromPath(
         'pdfFile', // This 'fieldname' must match what Busboy expects in the Cloud Function
         pdfFile.path,
         // contentType: MediaType('application', 'pdf'), // Optional: set content type
       )
     );

     try {
       var streamedResponse = await request.send();
       var response = await http.Response.fromStream(streamedResponse);

       if (response.statusCode == 200) {
         var responseData = jsonDecode(response.body);
         // Assuming Option A (GCS URI) from the Cloud Function
         return responseData['markdownGcsUri']; 
         // If Option B (direct markdown):
         // return response.body; 
       } else {
         print('Failed to convert PDF: ${response.statusCode} - ${response.body}');
         return null;
       }
     } catch (e) {
       print('Error uploading/converting PDF: $e');
       return null;
     }
   }
   ```

### 2.4. Process the Markdown
   - Once you receive the GCS URI (or Markdown text) from the Cloud Function:
     - **If GCS URI (Option A):**
       - You can now pass this GCS URI to your `FirebaseVertexaiService`.
       - You'll need a method in `FirebaseVertexaiService` similar to `analyzeUploadedMarkdownFile` (from the previous plan `react_pdf_to_md_integration_plan.md`) that accepts a GCS URI. The `FileData` object in Vertex AI SDKs can often directly consume GCS URIs if the service has appropriate permissions.
       ```dart
       // In FirebaseVertexaiService.dart (conceptual, adapt from previous plan)
       // Future<String> analyzeMarkdownFromGcs(String gcsUri) async {
       //   final String mimeType = "text/markdown";
       //   final model = _createModel(...); // Your existing model creation
       //   final TextPart prompt = TextPart("Analyze this Markdown...");
       //   final filePart = FileData(mimeType, gcsUri); // Vertex AI SDK handles GCS URI
       //
       //   // ... rest of the analysis logic (countTokens, generateContent)
       // }
       ```

### 2.5. UI/UX Considerations
   - Show loading indicators while the file is being uploaded and processed.
   - Display clear error messages if the conversion or upload fails.
   - Provide feedback to the user upon successful conversion and when analysis starts.

## 3. Security Considerations

### 3.1. Secure the Cloud Function
   - **Authentication:** By default, HTTP-triggered Cloud Functions are public.
     - If only authenticated Firebase users should access it, check for a Firebase Auth ID token in the `Authorization` header of the request within your Cloud Function.
     - For more complex scenarios, consider API Gateway or other authorization mechanisms.
   - **Input Validation:** Ensure the Cloud Function robustly validates inputs (e.g., file type, size limits) to prevent abuse. The example includes a basic MIME type check.

### 3.2. Firebase Storage Rules
   - As mentioned in 1.6, ensure your Storage rules are secure, granting minimal necessary permissions.

## 4. Testing

### 4.1. Cloud Function Testing
   - **Local Emulation:** Use the Firebase Local Emulator Suite to test your function locally before deploying.
     ```powershell
     firebase emulators:start --only functions,storage
     ```
   - **Manual Testing:** Use tools like Postman or `curl` to send PDF files to your deployed (or emulated) function URL and inspect the response.
   - **Unit Tests:** Write unit tests for your Cloud Function logic if it becomes complex.

### 4.2. Flutter App Testing
   - Test the file picking flow.
   - Test the HTTP request to the Cloud Function with actual PDF files.
   - Verify that the GCS URI or Markdown is correctly received.
   - Test the subsequent analysis flow with `FirebaseVertexaiService`.
   - Test error handling for network issues, conversion failures, etc.

## 5. Iteration & Refinements
- Monitor Cloud Function logs and performance in the Firebase console.
- Optimize as needed (e.g., memory allocation for the function, timeout settings).
- Gather user feedback on the new PDF processing workflow.

This plan provides a comprehensive guide to setting up a backend PDF-to-Markdown conversion service. Remember to replace placeholders like `YOUR_CLOUD_FUNCTION_URL_HERE` with your actual values.
