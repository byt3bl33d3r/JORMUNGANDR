using System;
using System.Net;
using System.Collections.Generic;

namespace JORMUNGANDR
{
    public class Http
    {
        public static string getPipUrl = "https://bootstrap.pypa.io/get-pip.py";

        public static Dictionary<int, string> urlsToArch = new Dictionary<int, string>
        {
            { 8, "https://www.python.org/ftp/python/3.7.7/python-3.7.7-embed-amd64.zip" },
            { 4, "https://www.python.org/ftp/python/3.7.7/python-3.7.7-embed-win32.zip"}
        };

        static Http()
        {
            ServicePointManager.ServerCertificateValidationCallback += (sender, cert, chain, sslPolicyErrors) => true;
            ServicePointManager.SecurityProtocol = (SecurityProtocolType)768 | (SecurityProtocolType)3072;
            ServicePointManager.Expect100Continue = false;
        }

        public static byte[] DownloadData(string url)
        {
            byte[] data;

            try
            {
                IWebProxy proxy = WebRequest.DefaultWebProxy;
                proxy.Credentials = CredentialCache.DefaultCredentials;
                using (WebClient webClient = new WebClient { Proxy = proxy })
                {
                    webClient.Credentials = CredentialCache.DefaultNetworkCredentials;
                    data = webClient.DownloadData(url);
                }
                return data;
            }
            catch (Exception)
            {
                Console.WriteLine($"Failed to download File: {url}");
                return default;
            }
        }

        public static bool DownloadToFile(string url, string fileName)
        {
            try
            {
                IWebProxy proxy = WebRequest.DefaultWebProxy;
                proxy.Credentials = CredentialCache.DefaultCredentials;
                using (WebClient webClient = new WebClient{ Proxy = proxy })
                {
                    webClient.Credentials = CredentialCache.DefaultNetworkCredentials;
                    webClient.DownloadFile(url, fileName);
                    return true;
                }
            }
            catch (Exception)
            {
                Console.WriteLine($"Failed to download File: {url}");
                return false;
            }
        }
    }
}