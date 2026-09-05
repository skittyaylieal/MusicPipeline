using System.Reflection;
using MusicPipeline.Colours;
using MusicPipeline.Profiles;
//using static System.Runtime.InteropServices.JavaScript.JSType;

namespace MusicPipelineTests
{
    public class Tests
    {
        [SetUp]
        public void Setup()
        {
        }

        [Test]
        public void TestCheckProfileToBeSaved()
        {
            FieldInfo[] fields = typeof(DefaultProfiles).GetFields();
            PropertyInfo[] fieldFields = typeof(Profile).GetProperties();
            Dictionary<KeyValuePair<string, Object?>, KeyValuePair<string, Object?>> fieldFieldsValues = new();

            for (int i = 0; i < fields.Length; i++)
            {
                Dictionary<string, bool> res = new();
                if (fields[i].FieldType == typeof(Profile))
                {
                    foreach (PropertyInfo p in fieldFields)
                    {
                        string temp1 = p.Name;
                        //await profile.LogEngine.Out(p.ToString() ?? "p was null lol", "SafetyChecker");
                        var profile = DefaultProfiles.DefaultProfile; //hopefully default profile is good enough to test with.
                        //Object? temp2 = p.GetValue(profile);

                        /* here's some new stuff to inspect with */
                        FieldInfo? fields_i = fields[i]; //this index is the type of profile, default, workingdefault, or error
                        PropertyInfo? profileFirstPropInfo_p = p; //this is a propinfo for a Profile property named "Name", not the value, but the property
                        
                        /*
                        documentation for PropInfo.GetValue() https://learn.microsoft.com/en-us/dotnet/api/system.reflection.propertyinfo.getvalue?view=net-10.0#system-reflection-propertyinfo-getvalue(system-object) 
                        
                        the error message is "Profile does not match type RtFieldInfo"
                        System.Reflection.RtFieldInfo is an internal runtime implementation class in .NET used to represent fields during reflection operations
                        */

                        //Object? temp3 = p.GetValue(fields[i]);

                        /* what you want is to get the value of the name property of your profile, not the value of a FieldInfo. */
                        var temp3 = p.GetValue(profile);

                        /* debugging this test gave me the answers I needed, but this isn't a real unit test */

                        //KeyValuePair<string, Object?> temp4 = new(temp1, temp2);
                        KeyValuePair<string, Object?> temp5 = new(temp1, temp3);
                        //KeyValuePair<KeyValuePair<string, Object?>, KeyValuePair<string, Object?>> temp6 = new(temp4, temp5);
                        //fieldFieldsValues.Append(temp6);
                        //if (p.GetValue(profile) == p.GetValue(fields[i]))
                        //{
                        //    res.Append(new(p.Name, true));
                        //}
                        //else { res.Append(new(p.Name, false)); }
                    }
                }
                //int count = 0;
                //string Out = "";
                //foreach (KeyValuePair<string, bool> kvp in res) { count += kvp.Value ? 1 : 0; string.Concat([Out, $"{kvp.Key} "]); }
                //bool a = res.Count() == count;
                //if (a) { return true; }
                //await(a ? profile.LogEngine.Out($"{profile.Name} is the exact same as the Default Profile, {fields[i].Name}", "SafetyChecker", DefaultColours.Warning, true) : profile.LogEngine.Out($"{count} Properties of {profile.Name} were the same as Default Profile {fields[i].Name}'s. They are: {Out}", "SafetyChecker"));
            }
            Assert.Pass();
        }
    }
}
