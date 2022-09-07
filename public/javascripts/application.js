$(function() {

  $("form.delete").submit(function(event) {
    event.preventDefault();
    event.stopPropagation();

    var ok = confirm("Are you sure? This action cannot be undone.");

    if (ok) {
      this.submit();
    };
  });

});
