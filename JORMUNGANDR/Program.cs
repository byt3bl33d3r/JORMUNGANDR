using System;
using System.Reflection;
using System.IO;
using Python.Runtime;
using System.Text;
using System.Runtime.InteropServices;

namespace JORMUNGANDR
{
    public class Program
    {
        static Guid folderGuid;
        static Guid sessionGuid;

        static Program()
        {
            AppDomain.CurrentDomain.AssemblyResolve += ResolveEventHandler;
            folderGuid = DeterministicGuid.Create(DeterministicGuid.DnsNamespace, Utils.GetLocalhostFqdn(), 5);
            sessionGuid = Guid.NewGuid();
        }

        private static Assembly ResolveEventHandler(object sender, ResolveEventArgs args)
        {
            var dllName = Utils.GetDllName(args.Name);
#if DEBUG
            Console.WriteLine($"[*] '{dllName}' was required...");
#endif

            byte[] bytes;
            bytes = Utils.GetResourceByName(dllName) ??
                    File.ReadAllBytes(RuntimeEnvironment.GetRuntimeDirectory() + dllName);

            return Assembly.Load(bytes);
        }

        public static void Main(string[] args)
        {
            AppDomain.CurrentDomain.AssemblyResolve -= ResolveEventHandler;
            Console.WriteLine($"\n[*] Install GUID: {folderGuid}");
            Console.WriteLine($"[*] Session GUID: {sessionGuid}\n");

            string appData = Environment.GetEnvironmentVariable("LOCALAPPDATA");
            string extractPath = Path.Combine(appData, "Temp", folderGuid.ToString());
            string pip_bootstrap = @"";

            if (!File.Exists(Path.Combine(extractPath, "python37.dll")))
            {
                Directory.CreateDirectory(extractPath);

                byte[] embeddedPythonZip = Utils.GetResourceByName(".zip") ??
                    Http.DownloadData(Http.urlsToArch[IntPtr.Size]);

                if (!Utils.VerifyMD5Hash(embeddedPythonZip, Utils.hashesToArch[IntPtr.Size]))
                {
                    return;
                }

                using (MemoryStream str = new MemoryStream(embeddedPythonZip))
                {
                    Utils.ZipExtract(str, extractPath);
                }

                Utils.WritePthFile(Path.Combine(extractPath, "python37._pth"));
                Directory.CreateDirectory(Path.Combine(extractPath, "Lib/site-packages/"));

                pip_bootstrap = Encoding.UTF8.GetString(Http.DownloadData(Http.getPipUrl));
                File.WriteAllText(Path.Combine(extractPath, "get-pip.py"), pip_bootstrap);
            }

            Environment.SetEnvironmentVariable("PATH", extractPath, EnvironmentVariableTarget.Process);
            Environment.SetEnvironmentVariable("PYTHONHOME", extractPath, EnvironmentVariableTarget.Process);
            Environment.SetEnvironmentVariable("PY_LIBS", Path.Combine(extractPath, "Lib"), EnvironmentVariableTarget.Process);
            Environment.SetEnvironmentVariable("PIP_LIBS", Path.Combine(extractPath, "Lib"), EnvironmentVariableTarget.Process);
            PythonEngine.PythonHome = extractPath;
            //PythonEngine.PythonPath = Environment.GetEnvironmentVariable("PYTHONPATH", EnvironmentVariableTarget.Process);
            Console.WriteLine($"{pip_bootstrap.Length}");
            RunPython(pip_bootstrap);
        }

        public static void RunPython(string pip_bootstrap)
        {
            // acquire the GIL before using the Python interpreter
            using (Py.GIL())
            {
                //PythonEngine.Exec(pip_bootstrap);
                // create a Python scope
                using (PyScope scope = Py.CreateScope())
                {
                    string code = $@"
import sys
import clr
import System
print(sys.path)
domain = System.AppDomain.CurrentDomain

for item in domain.GetAssemblies():
    print(item.GetName())

import pip
pip._internal.main(['install', '-t', 'Lib/site-packages', '--no-cache', '--no-cache-dir', 'terminaltables'])
";
                    scope.Exec(code);
                }
            }
        }
    }
}