module.exports = function() {
  var watch;

  watch = {
    options: {
      spawn: false
    },
    configFiles: {
      files: ["Gruntfile.js", "grunt/*.js"],
      options: {
        reload: true
      }
    },
    css: {
      files: [
        "assets/scss/*.scss",
        "assets/scss/**/*.scss",
        "assets/scss/**/**/*.scss"
      ],
      tasks: ["sass"]
    },
    js: {
      files: ["assets/js/**/*.js"],
      tasks: ["uglify"]
    },
    images: {
      files: ["public/img/*.*"],
      tasks: ["image"]
    }
  };

  return watch;
};
