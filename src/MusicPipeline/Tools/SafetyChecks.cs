using System.Reflection;
using MusicPipeline.Colours;
using MusicPipeline.Profiles;

namespace MusicPipeline.Tools.SafetyCheck;

public class SafetyCheck
{
	public static async Task<bool> CheckProfileToBeSaved(Profile profile)
	{
		// I Do not know what I'm doing
		FieldInfo[] fields = typeof(DefaultProfiles).GetFields();


		//Dictionary<string, Type> fieldInfo = new();
		//foreach (FieldInfo field in fields) {
			//fieldInfo.Append(new KeyValuePair<string, Type>(field.Name, field.FieldType));
		//}
		PropertyInfo[] fieldFields = typeof(Profile).GetProperties();
		Dictionary<KeyValuePair<string, Object?>, KeyValuePair<string, Object?>> fieldFieldsValues = new();
		
		for (int i = 0; i < fields.Length; i++) {
			// Ok
			// Now I have a list of Types and Names in the DefaultProfiles class
			// I need to go through each Profile in the class
			Dictionary<string, bool> res = new();
			if (fields[i].FieldType == typeof(Profile)) {
				// Now I need to compare this profile to the given one
				// Method by method
				
				foreach (PropertyInfo p in fieldFields) {
					KeyValuePair<string, Object?> temp1 = new(p.Name, p.GetValue(profile));
					KeyValuePair<string, Object?> temp2 = new(p.Name, p.GetValue(fields[i]));
					KeyValuePair<KeyValuePair<string, Object?>, KeyValuePair<string, Object?>> temp3 = new (temp1, temp2);
					fieldFieldsValues.Append(temp3);
					if (p.GetValue(profile) == p.GetValue(fields[i])) {
						res.Append(new (p.Name, true));
					}
					else {res.Append(new (p.Name, false));}
				}
			}
			int count = 0;
			string Out = "";
			foreach (KeyValuePair<string, bool> kvp in res) {count += kvp.Value ? 1:0; string.Concat([Out, $"{kvp.Key} "]);}
			bool a = res.Count() == count;
			if (a) {return true;}
			await (a ? profile.LogEngine.Out($"{profile.Name} is the exact same as the Default Profile, {fields[i].Name}", "SafetyChecker", DefaultColours.Warning, true) : profile.LogEngine.Out($"{count} Properties of {profile.Name} were the same as Default Profile {fields[i].Name}'s. They are: {Out}", "SafetyChecker"));
		}
		// So now we have a list of values and names, first from the profile, then from each defaultProfile
		// Ok
		// So
		// For each Profile in DefaultProfiles
		// We need to compare all its methods
		// To the same method in profile
		// We have all the data for doing this
		// All that's left is making something that uses this data to actually do what I want
		// "Ok what do you want?"
		// Well it needs to output whether its the same as any
		// Then log whats the same
		return false;
		
	}
}