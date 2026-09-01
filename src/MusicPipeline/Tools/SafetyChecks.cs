using System.Reflection;
using MusicPipeline.Colours;
using MusicPipeline.Profiles;

namespace MusicPipeline.Tools.SafetyCheck;

public class SafetyCheck
{
	public static async Task<bool> CheckProfileToBeSaved(Profile profile)
	{
		// I Do not know what I'm doing
		PropertyInfo[] fields = typeof(DefaultProfiles).GetProperties();


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
			if (fields[i].PropertyType == typeof(Profile)) {
				// Now I need to compare this profile to the given one
				// Method by method
				
				foreach (PropertyInfo p in fieldFields) {
					string temp1 = p.Name;
					await profile.LogEngine.Out(p.ToString() ?? "p was null lol", "SafetyChecker");
					Object? temp2 = p.GetValue(profile);
                     
					//ok, so the line below is throwing the error.
					//the reason is because it doesn't make any sense :)
					//temp2 makes sense. you're getting the Name property from an instance of Profile, and Profile has a property named Name.
					//temp3 you're trying to get the Name property from an instance of FieldInfo. The FieldInfo class doesn't have a property named Name.
					//What were you wanting temp3 to be? temp2 is already doing something nice.
					// temp3 needs to be a string like temp2
					// In this case
					// I need to get a Profile from the fieldinfo
					// 
					
                    Object? temp3 = p.GetValue(fields[i].GetMethod);
					KeyValuePair<string, Object?> temp4 = new(temp1, temp2);
					KeyValuePair<string, Object?> temp5 = new(temp1, temp3);
					KeyValuePair<KeyValuePair<string, Object?>, KeyValuePair<string, Object?>> temp6 = new (temp4, temp5);
					fieldFieldsValues.Append(temp6);
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