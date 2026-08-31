using System.Reflection;
using MusicPipeline.Profiles;

namespace MusicPipeline.Tools.SafetyCheck;

public class SafetyCheck
{
	public static async Task CheckProfileToBeSaved(Profile profile)
	{
		var fields = typeof(DefaultProfiles).GetFields();
		Dictionary<string, Type> fieldInfo = new();
		foreach (FieldInfo field in fields) {
			fieldInfo.Append(new KeyValuePair<string, Type>(field.Name, field.FieldType));
		}
		for (int i = 0; i < fields.Length; i++) {
			// Ok
			// Now I have a list of Types and Names in the DefaultProfiles class
			// I need to go through each Profile in the class
			if (fields[i].FieldType == typeof(Profile)) {
				// Now I need to compare this profile to the given one
				// Method by method
				PropertyInfo[] fieldFields = typeof(Profile).GetProperties();
				List<Object> fieldFieldValues = new List<Object>();
				foreach (PropertyInfo p in fieldFields) {
					fieldFieldValues.Append(p.GetValue(fields[i]));
					

				}
			}
		}
	}
}