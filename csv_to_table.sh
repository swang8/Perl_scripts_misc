perl -ne 'BEGIN{$f=$ARGV[0];  print "<p>The file is here <a href=\"$f\">$f</a></p>\n"; print "<table id=\"myTable\" class=\"table table-striped\">\n"}chomp; $n++; @t=split /,/, $_; @p=(); if($n==1){ map{push @p, "<th>".$_."</th>"}@t; print join(" ", "<thead> <tr>", @p, "</tr> </thead>"),"\n"  }   map{push @p, "<td>".$_."</td>"}@t; print join(" ", "<tr>", @p, "</tr>"),"\n"; 
END{
print "</table>";
print STDERR q{
Add the following to the head of your html to make a dynamic table:

  <link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/v/bs4/dt-1.10.18/datatables.min.css"/>
  <script type="text/javascript" src="https://cdn.datatables.net/v/bs4/dt-1.10.18/datatables.min.js"></script>
  <script>
    $(document).ready(function () {
    $('#myTable').DataTable(
      {
          "order": [[ 2, "desc" ]],
          "scrollY":        "400px",
          "scrollCollapse": true,
          "paging":         false
      }
    );
  });
  </script>

};

}' $1
