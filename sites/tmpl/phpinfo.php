<?php
echo session_start() . "<br>\n";
echo session_id() . "<br>\n";
echo var_dump($_SESSION) . "<br>\n";

$host = "www.medienhof.org";

echo "gethostbyname<br>\n";
$ip = gethostbyname($host);
echo var_dump($ip) . "<br>\n";
echo "...done<br>\n";

$checkHostA = checkdnsrr($host, 'A');
echo "checkdnsrr: " . var_dump($checkHostA) . "<br>\n";
if ($checkHostA) {
    echo "A Record OK<br>\n";
}
$checkHostAAAA = checkdnsrr($host, 'AAAA');
echo "checkdnsrr: " . var_dump($checkHostAAAA) . "<br>\n";
if ($checkHostAAAA) {
    echo "AAAA Record OK<br>\n";
}

echo "Check fopen()<br>\n";
$fopen_handle = fopen("http://update.joomla.org/core/list.xml", "r");
$fopen_result = fread($fopen_handle, 8192);
echo var_dump($fopen_result);
echo "...done<br>\n";

echo "Check curl_()<br>\n";
$curl_url = "http://$_SERVER[HTTP_HOST]";
$curl_ch = curl_init();
curl_setopt($curl_ch, CURLOPT_URL, $curl_url);
curl_setopt($curl_ch, CURLOPT_IPRESOLVE, CURL_IPRESOLVE_V4);
curl_exec($curl_ch);
var_dump(curl_error($curl_ch));
echo "<br>\n";
curl_close($curl_ch);

echo "phpinfo()<br>\n";
phpinfo();
?>
