using System;
using System.IO;
using System.Threading.Tasks;
using Windows.Graphics.Imaging;
using Windows.Media.Ocr;
using Windows.Storage;

public class OcrHelper {
    public static string ExtractText(string path) {
        return Task.Run(async () => {
            var file = await StorageFile.GetFileFromPathAsync(path);
            using (var stream = await file.OpenAsync(FileAccessMode.Read)) {
                var decoder = await BitmapDecoder.CreateAsync(stream);
                var bitmap = await decoder.GetSoftwareBitmapAsync();
                var engine = OcrEngine.TryCreateFromUserProfileLanguages();
                var result = await engine.RecognizeAsync(bitmap);
                return result.Text;
            }
        }).GetAwaiter().GetResult();
    }
}
