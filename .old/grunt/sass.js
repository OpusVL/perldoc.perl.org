module.exports = function () {

  var sass;

  sass = {
    options: {
      style: 'compressed',
      sourceMap: false,
    },
    style: {
      files: {
        'outputs/public/css/main.min.css': 'assets/scss/main.scss'
      }
    },
  };

  return sass;

};
