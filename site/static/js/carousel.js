// Adapted from https://www.w3schools.com/howto/howto_js_slideshow.asp
function docReady(fn) {
    // see if DOM is already available
    if (document.readyState === "complete" || document.readyState === "interactive") {
        // call on next available tick
        setTimeout(fn, 1);
    } else {
        document.addEventListener("DOMContentLoaded", fn);
    }
}

docReady(function() {
    var slideshows = document.getElementsByClassName("slideshow-container");
    for (var i = 0; i < slideshows.length; i++) {
        let slide = slideshows[i];
        let slides = slide.getElementsByClassName("mySlides");
        let prevButton = slide.getElementsByClassName("prev")[0];
        let nextButton = slide.getElementsByClassName("next")[0];
        prevButton.addEventListener('click', changeSlide, false);
        nextButton.addEventListener('click', changeSlide, false);
        // Hide all the slides
        for (n = 0; n < slides.length; n++) {
            slides[n].style.display = "none";
            slides[n].classList.remove("active");
        }
        // Show the first slide
        slides[0].style.display = "block";
        slides[0].classList.add("active");
    }
});

function changeSlide(e) {
    e.preventDefault();
    parent = e.currentTarget.parentElement;
    if (e.currentTarget.className == "prev") {
        showSlide(parent, -1);
    } else {
        showSlide(parent, 1);
    }
}

function showSlide(parent, n) {
    let slides = parent.getElementsByClassName("mySlides");
    let current = parent.getElementsByClassName("active");
    let currentSlide = current[0];
    let currentIndex = Array.prototype.indexOf.call(slides, currentSlide);
    let newIndex = currentIndex + n;
    if (newIndex < 0) {
        newIndex = slides.length - 1;
    } else if (newIndex >= slides.length) {
        newIndex = 0;
    }
    currentSlide.style.display = "none";
    currentSlide.classList.remove("active");
    slides[newIndex].style.display = "block";
    slides[newIndex].classList.add("active");
}


// Next/previous controls
// function plusSlides(n) {
//     showSlides(slideIndex += n);
// }

// Thumbnail image controls
// function currentSlide(n) {
//     showSlides(slideIndex = n);
// }

//let slideIndex = 1;
//showSlides(slideIndex);
/*

function showSlides(n) {
    let i;
    let slides = document.getElementsByClassName("mySlides");
    if (n > slides.length) {slideIndex = 1}
    if (n < 1) {slideIndex = slides.length}
    for (i = 0; i < slides.length; i++) {
        slides[i].style.display = "none";
    }
    slides[slideIndex-1].style.display = "block";
    // let dots = document.getElementsByClassName("dot");
    // for (i = 0; i < dots.length; i++) {
    //     dots[i].className = dots[i].className.replace(" active", "");
    // }
    // dots[slideIndex-1].className += " active";
}

*/