module.exports = function() {
  var image
  image = {
    // static: {
    //   options: {
    //     optipng: false,
    //     pngquant: true,
    //     zopflipng: true,
    //     jpegRecompress: false,
    //     mozjpeg: true,
    //     guetzli: false,
    //     gifsicle: true,
    //     svgo: true
    //   },
    //   files: {
    //     'outputs/public/img/*.png': 'public/img/*.png',
    //     'outputs/public/img/*.jpg': 'public/img/*.jpg',
    //     'outputs/public/img/*.gif': 'public/img/*.gif'
    //   }
    // },
    dynamic: {
      options: {
        optipng: false,
        pngquant: false,
        zopflipng: false,
        jpegRecompress: false,
        mozjpeg: true,
        guetzli: false,
        gifsicle: true,
        svgo: true,
      },
      files: [
        {
          expand: true,
          cwd: 'assets/img/',
          src: ['**/*.{png,ico,jpg,svg,gif}'],
          dest: 'public/img/',
        },
      ],
    },
  }
  return image
}
