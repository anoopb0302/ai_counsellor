// import "@hotwired/turbo-rails"
// import "./controllers"
// Entry point for the build script in your package.json


// console.log("🔵 This is the ESBuild-based application.js");

import { Turbo } from "@hotwired/turbo-rails";
// import { Application } from "@hotwired/stimulus";

// Initialize Turbo
Turbo.start();

// Initialize Stimulus
// const application = Application.start();

// Import all controllers from the controllers directory
import "./controllers";

// Load additional JS dependencies (Ensuring compatibility)
// eg.
// import "flowbite";