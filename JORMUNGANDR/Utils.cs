using System;
using System.Linq;
using System.IO;
using System.Net.NetworkInformation;
using System.Security.Cryptography;
using System.Collections.Generic;
using System.IO.Compression;
using System.Text;

namespace JORMUNGANDR
{
    class Utils
    {
        public static Dictionary<int, string> hashesToArch = new Dictionary<int, string>
        {
            { 8, "6aa3b1c327561bda256f2deebf038dc9" },
            { 4, "29672b400490ea21995c6dbae4c4e1c8"}
        };

        internal static bool VerifyMD5Hash(byte[] input, string hash)
        {
            using (MD5 md5Hash = MD5.Create())
            {
                // Convert the input string to a byte array and compute the hash.
                byte[] data = md5Hash.ComputeHash(input);
                StringBuilder sBuilder = new StringBuilder();
                for (int i = 0; i < data.Length; i++)
                {
                    sBuilder.Append(data[i].ToString("x2"));
                }

                string hashOfInput = sBuilder.ToString();
                StringComparer comparer = StringComparer.OrdinalIgnoreCase;
                if (0 == comparer.Compare(hashOfInput, hash))
                {
                    Console.WriteLine("[+] Hash matches");
                    return true;
                }
                else
                {
                    Console.WriteLine("[-] Hash doesn't match");
                    return false;
                }
            }
        }

        public static string GetDllName(string name)
        {
            var dllName = name + ".dll";
            if (name.IndexOf(',') > 0)
            {
                dllName = name.Substring(0, name.IndexOf(',')) + ".dll";
            }

            return dllName;
        }

        public static string GetLocalhostFqdn()
        {
            var ipProperties = IPGlobalProperties.GetIPGlobalProperties();
            return string.Format($"{IntPtr.Size}.{ipProperties.HostName}.{ipProperties.DomainName}");
        }

        internal static byte[] GetResourceByName(string resName)
        {
            var asm = System.Reflection.Assembly.GetExecutingAssembly();
            var resource = asm.GetManifestResourceNames().FirstOrDefault(x => x.EndsWith(resName));
            if (!string.IsNullOrEmpty(resource))
            {
                using (var resourceStream = asm.GetManifestResourceStream(resource))
                {
                    Console.WriteLine($"\t[*] Found resource '{resource}'");
                    using (var memoryStream = new MemoryStream())
                    {
                        resourceStream?.CopyTo(memoryStream);
                        return memoryStream.ToArray();
                    }
                }
            }
            return default;
        }

        internal static Stream GetResourceStreamByName(string resName)
        {
            var asm = System.Reflection.Assembly.GetExecutingAssembly();
            var resource = asm.GetManifestResourceNames().FirstOrDefault(x => x.EndsWith(resName));
            if (!string.IsNullOrEmpty(resource))
            {
                Console.WriteLine($"\t[*] Found resource '{resource}'");
                return asm.GetManifestResourceStream(resource);
            }
            return default;
        }

        internal static void ZipExtract(Stream zipFile, string extractPath)
        {
            Console.WriteLine($"[*] Extracting to {extractPath}");
            using (ZipStorer zip = ZipStorer.Open(zipFile, FileAccess.Read, false))
            {
                List<ZipStorer.ZipFileEntry> dir = zip.ReadCentralDir();
                foreach (ZipStorer.ZipFileEntry entry in dir)
                {
                    string filename = Path.GetFileName(entry.FilenameInZip);
                    string path = Path.GetDirectoryName(entry.FilenameInZip);
                    if (!string.IsNullOrEmpty(filename))
                    {
                        if (!string.IsNullOrEmpty(path))
                        {
                            Directory.CreateDirectory(Path.Combine(extractPath, path));
                        }

                        string fullFilePath = Path.Combine(extractPath, path, filename);
                        Console.WriteLine($"\t[*] Extract file: {fullFilePath}");
                        using (FileStream fs = File.Create(fullFilePath))
                        {
                            zip.ExtractFile(entry, fs);
                        }
                    }
                }
            }
        }

        internal static bool WritePthFile(string filename)
        {
            Console.WriteLine("[*] Writing ._pth file");
            string[] pthfile = { "python37.zip", ".", "python37.zip/site-packages", "import site" };
            File.WriteAllLines(filename, pthfile);
            return true;
        }
    }

    public static class DeterministicGuid
    {
        /// <summary>
        /// Tries to parse the specified string as a <see cref="Guid"/>.  A return value indicates whether the operation succeeded.
        /// </summary>
        /// <param name="value">The GUID string to attempt to parse.</param>
        /// <param name="guid">When this method returns, contains the <see cref="Guid"/> equivalent to the GUID
        /// contained in <paramref name="value"/>, if the conversion succeeded, or Guid.Empty if the conversion failed.</param>
        /// <returns><c>true</c> if a GUID was successfully parsed; <c>false</c> otherwise.</returns>
        public static bool TryParse(string value, out Guid guid) => Guid.TryParse(value, out guid);

        /// <summary>
        /// Converts a GUID to a lowercase string with no dashes.
        /// </summary>
        /// <param name="guid">The GUID.</param>
        /// <returns>The GUID as a lowercase string with no dashes.</returns>
        public static string ToLowerNoDashString(this Guid guid) => guid.ToString("N");

        /// <summary>
        /// Converts a lowercase, no dashes string to a GUID.
        /// </summary>
        /// <param name="value">The string.</param>
        /// <returns>The GUID.</returns>
        /// <exception cref="FormatException">The argument is not a valid GUID short string.</exception>
        public static Guid FromLowerNoDashString(string value) =>
            TryFromLowerNoDashString(value) ?? throw new FormatException(string.Format("The string '{0}' is not a no-dash lowercase GUID.", value.ToString()));

        /// <summary>
        /// Attempts to convert a lowercase, no dashes string to a GUID.
        /// </summary>
        /// <param name="value">The string.</param>
        /// <returns>The GUID, if the string could be converted; otherwise, null.</returns>
        public static Guid? TryFromLowerNoDashString(string value) => !TryParse(value, out var guid) || value != guid.ToLowerNoDashString() ? default(Guid?) : guid;

        /// <summary>
        /// Creates a name-based UUID using the algorithm from RFC 4122 §4.3.
        /// </summary>
        /// <param name="namespaceId">The ID of the namespace.</param>
        /// <param name="name">The name (within that namespace).</param>
        /// <returns>A UUID derived from the namespace and name.</returns>
        public static Guid Create(Guid namespaceId, string name) => Create(namespaceId, name, 5);

        /// <summary>
        /// Creates a name-based UUID using the algorithm from RFC 4122 §4.3.
        /// </summary>
        /// <param name="namespaceId">The ID of the namespace.</param>
        /// <param name="name">The name (within that namespace).</param>
        /// <param name="version">The version number of the UUID to create; this value must be either
        /// 3 (for MD5 hashing) or 5 (for SHA-1 hashing).</param>
        /// <returns>A UUID derived from the namespace and name.</returns>
        public static Guid Create(Guid namespaceId, string name, int version)
        {
            if (name is null)
                throw new ArgumentNullException(nameof(name));

            // convert the name to a sequence of octets (as defined by the standard or conventions of its namespace) (step 3)
            // ASSUME: UTF-8 encoding is always appropriate
            return Create(namespaceId, Encoding.UTF8.GetBytes(name), version);
        }

        /// <summary>
        /// Creates a name-based UUID using the algorithm from RFC 4122 §4.3.
        /// </summary>
        /// <param name="namespaceId">The ID of the namespace.</param>
        /// <param name="nameBytes">The name (within that namespace).</param>
        /// <returns>A UUID derived from the namespace and name.</returns>
        public static Guid Create(Guid namespaceId, byte[] nameBytes) => Create(namespaceId, nameBytes, 5);

        /// <summary>
        /// Creates a name-based UUID using the algorithm from RFC 4122 §4.3.
        /// </summary>
        /// <param name="namespaceId">The ID of the namespace.</param>
        /// <param name="nameBytes">The name (within that namespace).</param>
        /// <param name="version">The version number of the UUID to create; this value must be either
        /// 3 (for MD5 hashing) or 5 (for SHA-1 hashing).</param>
        /// <returns>A UUID derived from the namespace and name.</returns>
        public static Guid Create(Guid namespaceId, byte[] nameBytes, int version)
        {
            if (version != 3 && version != 5)
                throw new ArgumentOutOfRangeException(nameof(version), "version must be either 3 or 5.");

            // convert the namespace UUID to network order (step 3)
            byte[] namespaceBytes = namespaceId.ToByteArray();
            SwapByteOrder(namespaceBytes);

            // compute the hash of the namespace ID concatenated with the name (step 4)
            byte[] data = namespaceBytes.Concat(nameBytes).ToArray();
            byte[] hash;
            using (var algorithm = version == 3 ? (HashAlgorithm)MD5.Create() : SHA1.Create())
                hash = algorithm.ComputeHash(data);

            // most bytes from the hash are copied straight to the bytes of the new GUID (steps 5-7, 9, 11-12)
            byte[] newGuid = new byte[16];
            Array.Copy(hash, 0, newGuid, 0, 16);

            // set the four most significant bits (bits 12 through 15) of the time_hi_and_version field to the appropriate 4-bit version number from Section 4.1.3 (step 8)
            newGuid[6] = (byte)((newGuid[6] & 0x0F) | (version << 4));

            // set the two most significant bits (bits 6 and 7) of the clock_seq_hi_and_reserved to zero and one, respectively (step 10)
            newGuid[8] = (byte)((newGuid[8] & 0x3F) | 0x80);

            // convert the resulting UUID to local byte order (step 13)
            SwapByteOrder(newGuid);
            return new Guid(newGuid);
        }

        /// <summary>
        /// The namespace for fully-qualified domain names (from RFC 4122, Appendix C).
        /// </summary>
        public static readonly Guid DnsNamespace = new Guid("6ba7b810-9dad-11d1-80b4-00c04fd430c8");

        /// <summary>
        /// The namespace for URLs (from RFC 4122, Appendix C).
        /// </summary>
        public static readonly Guid UrlNamespace = new Guid("6ba7b811-9dad-11d1-80b4-00c04fd430c8");

        /// <summary>
        /// The namespace for ISO OIDs (from RFC 4122, Appendix C).
        /// </summary>
        public static readonly Guid IsoOidNamespace = new Guid("6ba7b812-9dad-11d1-80b4-00c04fd430c8");

        // Converts a GUID (expressed as a byte array) to/from network order (MSB-first).
        internal static void SwapByteOrder(byte[] guid)
        {
            SwapBytes(guid, 0, 3);
            SwapBytes(guid, 1, 2);
            SwapBytes(guid, 4, 5);
            SwapBytes(guid, 6, 7);
        }

        private static void SwapBytes(byte[] guid, int left, int right)
        {
            byte temp = guid[left];
            guid[left] = guid[right];
            guid[right] = temp;
        }
    }
}